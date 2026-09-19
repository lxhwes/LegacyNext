local _, ns = ...

-- Pure Lua: challenge ranking, reward-track math, category grouping and the v0 view model.
-- No WoW globals at all, which is what makes this layer testable under busted -- and
-- spec/model/model_spec.lua runs it under an environment that errors on any global outside
-- the Lua 5.1 standard library, so a stray CreateFrame here fails a test rather than a player.
ns.Model = ns.Model or {}
local Model = ns.Model

--------------------------------------------------------------------------------------------
-- Scoring -- the one place closeness is defined
--------------------------------------------------------------------------------------------
--
-- Inputs are the challenge tables Api.GetChallenges returns. The rules below are the five
-- scoring decisions locked in docs/status.md ("Phase 3 readiness"); change one here and the
-- ranking changes everywhere, uidump included.
--
-- 1. A challenge with criteriaExpected == 0 is MEASURELESS. The client exposes no progress for
--    it, so it sorts below everything measurable rather than sitting at a permanent 0%.
--    Detected by the count, never by category or name.
-- 2. A challenge whose criteria list came back short (#criteria < criteriaExpected) is also
--    treated as measureless, flagged "partial read". Closeness off a truncated list is
--    silently wrong rather than absent.
-- 3. Per criterion: if `need` > 1 the criterion is a quantity and contributes have/need. That
--    covers progress-bar criteria AND the type-243 reputation criteria whose bar bit is clear
--    (0/42000 must not read as one step from done). Otherwise it is a boolean step: completed
--    contributes 1/1, incomplete 0/1.
-- 4. A challenge's fraction is the MEAN of its criteria fractions, so a reputation criterion
--    does not outweigh a dungeon criterion by 42000 to 1. The display figure is have/need for
--    a single criterion and done/total for a list.
-- 5. Sort order: measurable before measureless; then fraction remaining ascending; then
--    absolute steps remaining ascending (0/150 before 0/300, 0/6 before 0/17); then the
--    order the client listed them in, which is category order. Points are NOT a factor:
--    every point-bearing challenge awards 1 today.
--
-- Excluded from Next Up entirely (Model.Rank): completed challenges, and challenges whose
-- points read exactly 0 (the 46 Explore substrate achievements). A challenge whose points
-- could not be read (nil) is KEPT and flagged, because hiding rows on a failed read is the
-- failure mode nobody notices.

-- Client sentinel for "top-level category" -- Blizzard_LegacyChallengeTracker.lua:6 names it
-- TOP_LEVEL_CATEGORY_ID = -1. A nil parent is treated the same way.
Model.NO_PARENT = -1

local function toNumber(value, default)
	if type(value) == "number" then
		return value
	end
	return default
end

-- One criterion, normalised to have/need with need >= 1 and have clamped into [0, need].
local function criterionProgress(criterion)
	local need = toNumber(criterion.need, 1)
	if need < 1 then
		need = 1
	end

	local have
	if criterion.completed then
		have = need
	else
		have = toNumber(criterion.have, 0)
		if have < 0 then
			have = 0
		elseif have > need then
			have = need
		end
	end

	return {
		text = criterion.text,
		have = have,
		need = need,
		completed = criterion.completed and true or false,
		isQuantity = need > 1,
	}
end

-- Progress for one challenge. Always returns a table; `measurable` says whether the numbers
-- mean anything, and `reason` says why not when they do not.
function Model.Progress(challenge)
	local criteria = challenge.criteria
	local expected = toNumber(challenge.criteriaExpected, 0)

	if type(criteria) ~= "table" or expected <= 0 or #criteria == 0 then
		return { measurable = false, reason = "no criteria", lines = {} }
	end

	if #criteria < expected then
		return {
			measurable = false,
			reason = "partial read",
			criteriaRead = #criteria,
			criteriaTotal = expected,
			lines = {},
		}
	end

	local lines = {}
	local sumFraction, done, remaining = 0, 0, 0
	for index, criterion in ipairs(criteria) do
		local line = criterionProgress(criterion)
		lines[index] = line
		sumFraction = sumFraction + line.have / line.need
		remaining = remaining + (line.need - line.have)
		if line.completed or line.have >= line.need then
			done = done + 1
		end
	end

	local have, need
	if #lines == 1 then
		have, need = lines[1].have, lines[1].need
	else
		have, need = done, #lines
	end

	return {
		measurable = true,
		have = have,
		need = need,
		fraction = sumFraction / #lines,
		remaining = remaining,
		criteriaDone = done,
		criteriaTotal = #lines,
		lines = lines,
	}
end

-- Sort comparator over ranked entries ({ challenge, progress, index }). Documented above as
-- rule 5. Kept separate so a tuning change is one function.
function Model.Compare(a, b)
	local pa, pb = a.progress, b.progress
	if pa.measurable ~= pb.measurable then
		return pa.measurable
	end

	if pa.measurable then
		local ra, rb = 1 - pa.fraction, 1 - pb.fraction
		if ra ~= rb then
			return ra < rb
		end
		if pa.remaining ~= pb.remaining then
			return pa.remaining < pb.remaining
		end
	end

	return a.index < b.index
end

-- Whether a challenge belongs in Next Up at all.
function Model.IsNextUp(challenge)
	if challenge.completed then
		return false, "completed"
	end
	if challenge.points == 0 then
		return false, "zero points"
	end
	return true
end

-- The ranked list plus a tally of what was excluded and why. Entries carry the original
-- challenge, its progress and its position in the client's list.
function Model.Rank(challenges)
	local entries = {}
	local stats = {
		total = 0,
		completed = 0,
		zeroPoint = 0,
		ranked = 0,
		measurable = 0,
		measureless = 0,
		partialRead = 0,
		pointsUnknown = 0,
	}

	for index, challenge in ipairs(challenges or {}) do
		stats.total = stats.total + 1
		local keep, why = Model.IsNextUp(challenge)
		if not keep then
			if why == "completed" then
				stats.completed = stats.completed + 1
			else
				stats.zeroPoint = stats.zeroPoint + 1
			end
		else
			local progress = Model.Progress(challenge)
			entries[#entries + 1] = {
				challenge = challenge,
				progress = progress,
				index = index,
				groupId = Model.GroupOf(challenge),
			}
			stats.ranked = stats.ranked + 1
			if progress.measurable then
				stats.measurable = stats.measurable + 1
			else
				stats.measureless = stats.measureless + 1
				if progress.reason == "partial read" then
					stats.partialRead = stats.partialRead + 1
				end
			end
			if challenge.points == nil then
				stats.pointsUnknown = stats.pointsUnknown + 1
			end
		end
	end

	table.sort(entries, Model.Compare)
	return entries, stats
end

--------------------------------------------------------------------------------------------
-- Categories
--------------------------------------------------------------------------------------------

-- The filter group a challenge belongs to: its parent category when it has one, otherwise
-- its own category. The tree is two levels deep, so this is the top level.
function Model.GroupOf(challenge)
	local parent = challenge.parentCategoryId
	if type(parent) == "number" and parent ~= Model.NO_PARENT then
		return parent
	end
	return challenge.categoryId
end

-- Top-level groups that actually hold ranked entries, in the client's category order when a
-- category list is supplied and in first-seen order otherwise. Groups with nothing in them
-- never appear, which is what drops "Do Not Display" -- by count, never by name.
--
-- `categories` is Api.GetCategories output: { { id, name, parentId }, ... }. It is the only
-- source for the name of a parent that has no challenges of its own (Classes, Tradeskills,
-- Player vs. Player); without it those groups are named by id.
function Model.Groups(entries, categories)
	local counts, firstSeen, ownName = {}, {}, {}
	for _, entry in ipairs(entries) do
		local id = entry.groupId
		if not counts[id] then
			counts[id] = 0
			firstSeen[#firstSeen + 1] = id
		end
		counts[id] = counts[id] + 1
		if entry.challenge.categoryId == id and entry.challenge.categoryName then
			ownName[id] = entry.challenge.categoryName
		end
	end

	local names, clientOrder = {}, {}
	for _, category in ipairs(type(categories) == "table" and categories or {}) do
		if type(category.id) == "number" then
			names[category.id] = category.name
			clientOrder[#clientOrder + 1] = category.id
		end
	end

	-- Client order first, then anything the category list did not mention.
	local order, placed = {}, {}
	for _, id in ipairs(clientOrder) do
		if counts[id] and not placed[id] then
			order[#order + 1] = id
			placed[id] = true
		end
	end
	for _, id in ipairs(firstSeen) do
		if not placed[id] then
			order[#order + 1] = id
			placed[id] = true
		end
	end

	local groups = {}
	for _, id in ipairs(order) do
		groups[#groups + 1] = {
			id = id,
			name = names[id] or ownName[id] or ("Category " .. tostring(id)),
			count = counts[id],
		}
	end
	return groups
end

-- Entries in one group, or all of them when groupId is nil.
function Model.Filter(entries, groupId)
	if groupId == nil then
		return entries
	end
	local out = {}
	for _, entry in ipairs(entries) do
		if entry.groupId == groupId then
			out[#out + 1] = entry
		end
	end
	return out
end

--------------------------------------------------------------------------------------------
-- Reward track
--------------------------------------------------------------------------------------------

local function rewardName(reward)
	if type(reward) ~= "table" then
		return nil
	end
	return reward.name or reward.toastDescription
end

-- Header numbers from Api.GetRewardTrack output. The next threshold is recomputed from the
-- sparse threshold list rather than trusted from Api, so a level change between two reads
-- cannot leave the two disagreeing.
function Model.RewardSummary(track)
	if type(track) ~= "table" then
		return nil, "no reward track"
	end

	local earned = toNumber(track.earned, toNumber(track.level, nil))
	local summary = {
		name = track.name,
		earned = earned,
		maxLevel = track.maxLevel,
		nextThreshold = nil,
		pointsToNext = nil,
		nextRewardNames = {},
		thresholdsReached = 0,
		thresholdsTotal = 0,
		complete = false,
	}

	local thresholds = type(track.thresholds) == "table" and track.thresholds or {}
	summary.thresholdsTotal = #thresholds

	for _, threshold in ipairs(thresholds) do
		local level = toNumber(threshold.level, nil)
		if level and earned then
			if earned >= level then
				summary.thresholdsReached = summary.thresholdsReached + 1
			elseif not summary.nextThreshold then
				summary.nextThreshold = level
				summary.pointsToNext = level - earned
				for _, reward in ipairs(threshold.rewards or {}) do
					local name = rewardName(reward)
					if name then
						summary.nextRewardNames[#summary.nextRewardNames + 1] = name
					end
				end
			end
		end
	end

	if not summary.nextThreshold then
		-- Api's own reading, only for a track whose threshold list did not come back.
		if #thresholds == 0 and type(track.nextThreshold) == "number" then
			summary.nextThreshold = track.nextThreshold
			summary.pointsToNext = track.pointsToNext
			for _, reward in ipairs(track.nextRewards or {}) do
				local name = rewardName(reward)
				if name then
					summary.nextRewardNames[#summary.nextRewardNames + 1] = name
				end
			end
		elseif #thresholds > 0 and earned then
			summary.complete = true
		end
	end

	return summary
end

--------------------------------------------------------------------------------------------
-- The v0 view
--------------------------------------------------------------------------------------------

Model.SEPARATOR = "  \194\183  " -- middle dot; one constant so it can change if the font lacks it
Model.DIVIDER_TEXT = "no progress shown"
Model.ALL_LABEL = "All"

local function pointsText(points)
	if type(points) ~= "number" then
		return "?pt"
	end
	return tostring(points) .. "pt"
end

local function progressText(progress)
	if progress.measurable then
		return tostring(progress.have) .. "/" .. tostring(progress.need)
	end
	if progress.reason == "partial read" then
		return "?"
	end
	return ""
end

local function headerLines(summary, reason)
	if not summary then
		return {
			"Legacy Track" .. Model.SEPARATOR .. "unavailable",
			reason and ("Could not read the reward track: " .. tostring(reason)) or "",
		}
	end

	local name = summary.name or "Legacy Track"
	local earned = summary.earned
	local first
	if summary.complete then
		first = name .. Model.SEPARATOR .. tostring(earned) .. " pts" .. Model.SEPARATOR
			.. "all rewards reached"
	elseif summary.pointsToNext then
		first = name .. Model.SEPARATOR .. tostring(earned) .. " pts" .. Model.SEPARATOR
			.. tostring(summary.pointsToNext) .. " to next"
	elseif earned then
		first = name .. Model.SEPARATOR .. tostring(earned) .. " pts"
	else
		first = name
	end

	local second
	if #summary.nextRewardNames > 0 then
		second = "Next: " .. table.concat(summary.nextRewardNames, ", ")
	elseif summary.complete then
		second = ""
	elseif summary.nextThreshold then
		second = "Next reward at " .. tostring(summary.nextThreshold)
	else
		second = "No reward thresholds reported"
	end

	return { first, second }
end

-- Tooltip content for one row: the description, then one line per criterion.
local function detailLines(entry)
	local challenge, progress = entry.challenge, entry.progress
	local lines = {}
	if challenge.description and challenge.description ~= "" then
		lines[#lines + 1] = challenge.description
	end
	for _, line in ipairs(progress.lines) do
		local mark = (line.completed or line.have >= line.need) and "[x] " or "[ ] "
		local figure = line.isQuantity and (" " .. tostring(line.have) .. "/" .. tostring(line.need)) or ""
		lines[#lines + 1] = mark .. tostring(line.text or "") .. figure
	end
	if progress.reason == "partial read" then
		lines[#lines + 1] = "Only " .. tostring(progress.criteriaRead) .. " of "
			.. tostring(progress.criteriaTotal) .. " criteria could be read"
	end
	if challenge.rewardText and challenge.rewardText ~= "" then
		lines[#lines + 1] = challenge.rewardText
	end
	return lines
end

-- Everything the frame and /lgn uidump render, computed once from Api output.
--
-- input = {
--   challenges = list | nil,  challengesReason = string | nil,
--   rewardTrack = table | nil, rewardTrackReason = string | nil,
--   categories = list | nil,
--   filter = groupId | nil,
-- }
function Model.BuildView(input)
	input = input or {}
	local view = {
		header = {},
		filters = {},
		rows = {},
		state = "ok",
		message = nil,
		stats = nil,
	}

	local summary, summaryReason = Model.RewardSummary(input.rewardTrack)
	view.header = {
		lines = headerLines(summary, input.rewardTrackReason or summaryReason),
		summary = summary,
		state = summary and "ok" or "error",
		reason = summary and nil or (input.rewardTrackReason or summaryReason),
	}

	if type(input.challenges) ~= "table" then
		view.state = "error"
		view.message = "Could not read your challenges"
			.. (input.challengesReason and (": " .. tostring(input.challengesReason)) or "")
		return view
	end

	local entries, stats = Model.Rank(input.challenges)
	view.stats = stats

	if stats.total == 0 then
		view.state = "empty"
		view.message = "No Legacy challenges found"
		return view
	end

	local groups = Model.Groups(entries, input.categories)
	local filter = input.filter
	local filterKnown = filter == nil
	for _, group in ipairs(groups) do
		if group.id == filter then
			filterKnown = true
		end
	end
	if not filterKnown then
		filter = nil
	end
	view.filter = filter

	view.filters[1] = { id = nil, name = Model.ALL_LABEL, count = #entries, selected = filter == nil }
	for _, group in ipairs(groups) do
		view.filters[#view.filters + 1] = {
			id = group.id,
			name = group.name,
			count = group.count,
			selected = group.id == filter,
		}
	end

	local visible = Model.Filter(entries, filter)
	if #visible == 0 then
		view.state = "done"
		if filter == nil then
			view.message = "Nothing left to earn"
		else
			view.message = "Nothing left to earn in this category"
		end
		return view
	end

	local dividerPlaced = false
	for _, entry in ipairs(visible) do
		if not entry.progress.measurable and not dividerPlaced then
			view.rows[#view.rows + 1] = { kind = "divider", text = Model.DIVIDER_TEXT }
			dividerPlaced = true
		end
		view.rows[#view.rows + 1] = {
			kind = "challenge",
			id = entry.challenge.id,
			name = entry.challenge.name or ("Challenge " .. tostring(entry.challenge.id)),
			category = entry.challenge.categoryName,
			progressText = progressText(entry.progress),
			pointsText = pointsText(entry.challenge.points),
			measurable = entry.progress.measurable,
			detail = detailLines(entry),
			entry = entry,
		}
	end

	return view
end
