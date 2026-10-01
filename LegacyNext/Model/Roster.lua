local _, ns = ...

-- v1 Roster, pure Lua: per-character snapshots, the roster view, and which alt is closest to
-- each tradeskill challenge. Same rule as Model.lua -- no WoW globals, enforced by the strict
-- environment in spec/model/roster_spec.lua.
--
-- Mapping covers profession challenges only (Alex, 2026-09-30). Class-leveling challenges
-- carry no machine-readable level (CLAUDE.md), so they get no candidate.
ns.Model = ns.Model or {}
local Model = ns.Model

-- criteriaType 7 is a skill threshold: assetId is a skill line, need is the skill level
-- (CLAUDE.md, criteriaType axis). Only this one value is read; every other type is ignored,
-- never switched on.
Model.CRITERIA_TYPE_SKILL = 7

--------------------------------------------------------------------------------------------
-- Snapshots
--------------------------------------------------------------------------------------------

-- "Name-Realm". The captured Shaman has both fields (spec/fixtures/dump_character_shaman.lua).
function Model.CharacterKey(character)
	if type(character) ~= "table" then
		return nil, "no character"
	end
	local name, realm = character.name, character.realm
	if type(name) ~= "string" or name == "" then
		return nil, "no name"
	end
	if type(realm) ~= "string" or realm == "" then
		return nil, "no realm"
	end
	return name .. "-" .. realm
end

local function snapshotProfessions(list)
	local out = {}
	for _, profession in ipairs(list) do
		if type(profession) == "table" then
			out[#out + 1] = {
				name = profession.name,
				skillLineId = profession.skillLineId,
				skill = profession.skill,
				max = profession.max,
			}
		end
	end
	return out
end

-- Api.GetTreeSpend returns a table even when every currency read failed -- the tree ids come
-- from constants with fallbacks -- so a non-nil spend proves nothing. The read counts only if
-- the pool's unspent and every tree's spentInTree came back as numbers.
local function snapshotTrees(treeSpend)
	if type(treeSpend.unspent) ~= "number" then
		return nil, "unspent points not read"
	end
	local trees, unread = {}, {}
	for _, treeId in ipairs(treeSpend.treeIds or {}) do
		local tree = treeSpend[treeId]
		if type(tree) == "table" and type(tree.spentInTree) == "number" then
			trees[#trees + 1] = { treeId = treeId, name = tree.name, spent = tree.spentInTree }
		else
			unread[#unread + 1] = tostring(treeId)
		end
	end
	if unread[1] then
		return nil, "tree spend not read for " .. table.concat(unread, ", ")
	end
	if not trees[1] then
		return nil, "no trees"
	end
	return trees
end

--- One character's snapshot from this session's reads.
-- input = { character, treeSpend, treeSpendReason, now }: Api.GetCharacterInfo,
-- Api.GetTreeSpend and Api.GetServerTime output. A part that failed to read is left nil with
-- its reason, so MergeSnapshot can keep the last good value instead of overwriting it.
function Model.BuildSnapshot(input)
	input = input or {}
	local character = input.character
	local key, keyReason = Model.CharacterKey(character)
	if not key then
		return nil, keyReason
	end

	local snapshot = {
		key = key,
		name = character.name,
		realm = character.realm,
		class = character.class,
		classToken = character.classToken,
		level = character.level,
		takenAt = input.now,
	}

	-- A list with a reason beside it is a partial read (Api names the slots that failed), and
	-- counts as no read: it would erase the professions it missed.
	if type(character.professions) == "table" and character.professionsReason == nil then
		snapshot.professions = snapshotProfessions(character.professions)
		snapshot.professionsAt = input.now
	else
		snapshot.professionsReason = character.professionsReason or "not read"
	end

	local spend = input.treeSpend
	local trees, treesReason = nil, input.treeSpendReason or "not read"
	if type(spend) == "table" then
		trees, treesReason = snapshotTrees(spend)
	end
	if trees then
		snapshot.trees = trees
		snapshot.spent = spend.spent
		snapshot.unspent = spend.unspent
		snapshot.cap = spend.cap
		snapshot.treesAt = input.now
	else
		snapshot.treesReason = treesReason
	end

	return snapshot
end

local KEEP_IF_MISSING = { "class", "classToken", "level" }

--- A fresh snapshot laid over the stored one. Anything the fresh read failed to get is kept
-- from before, with its old timestamp, so a failed read at logout never erases an alt's
-- professions or tree spend.
function Model.MergeSnapshot(previous, fresh)
	if type(previous) ~= "table" or previous.key ~= fresh.key then
		return fresh
	end

	local merged = {}
	for field, value in pairs(fresh) do
		merged[field] = value
	end

	for _, field in ipairs(KEEP_IF_MISSING) do
		if merged[field] == nil then
			merged[field] = previous[field]
		end
	end

	-- An empty read over a stored list is kept as a failed one too: skill data may not be ready
	-- when a snapshot fires, and a character that really dropped both professions costs only a
	-- stale row until /lgn roster forget.
	local freshEmpty = type(fresh.professions) == "table" and fresh.professions[1] == nil
	local previousHas = type(previous.professions) == "table" and previous.professions[1] ~= nil
	if (fresh.professions == nil and previous.professions ~= nil) or (freshEmpty and previousHas) then
		merged.professions = previous.professions
		merged.professionsAt = previous.professionsAt
		if freshEmpty then
			merged.professionsReason = "empty read, kept stored"
		end
	end

	if fresh.trees == nil and previous.trees ~= nil then
		merged.trees = previous.trees
		merged.spent = previous.spent
		merged.unspent = previous.unspent
		merged.cap = previous.cap
		merged.treesAt = previous.treesAt
	end

	return merged
end

--------------------------------------------------------------------------------------------
-- Roster
--------------------------------------------------------------------------------------------

--- Every stored character, current one first, then by level (highest first), then by key.
-- A snapshot that is not a table or has no key is skipped and counted.
function Model.Roster(snapshots, currentKey)
	local rows, skipped = {}, 0
	for _, snapshot in ipairs(snapshots or {}) do
		if type(snapshot) == "table" and type(snapshot.key) == "string" then
			rows[#rows + 1] = snapshot
		else
			skipped = skipped + 1
		end
	end

	table.sort(rows, function(a, b)
		local aCurrent, bCurrent = a.key == currentKey, b.key == currentKey
		if aCurrent ~= bCurrent then
			return aCurrent
		end
		local aLevel = type(a.level) == "number" and a.level or -1
		local bLevel = type(b.level) == "number" and b.level or -1
		if aLevel ~= bLevel then
			return aLevel > bLevel
		end
		return a.key < b.key
	end)

	return { rows = rows, skipped = skipped, currentKey = currentKey }
end

--------------------------------------------------------------------------------------------
-- Profession candidates
--------------------------------------------------------------------------------------------

local function skillCriterion(challenge)
	for _, criterion in ipairs(challenge.criteria or {}) do
		if criterion.criteriaType == Model.CRITERIA_TYPE_SKILL
			and type(criterion.assetId) == "number" and criterion.assetId > 0
			and type(criterion.need) == "number" and criterion.need > 0 then
			return criterion
		end
	end
	return nil
end

--- The distinct skill lines tradeskill challenges name, for Api.GetSkillLineParents.
function Model.ChallengeSkillLines(challenges)
	local ids, seen = {}, {}
	for _, challenge in ipairs(challenges or {}) do
		local criterion = skillCriterion(challenge)
		if criterion and not seen[criterion.assetId] then
			seen[criterion.assetId] = true
			ids[#ids + 1] = criterion.assetId
		end
	end
	return ids
end

local function effectiveId(parent)
	return type(parent) == "table" and (parent.parentId or parent.professionId) or nil
end

-- The effective id when it adds a way to join: an answer naming the line itself only repeats
-- the direct match.
local function joinId(parent, skillLineId)
	local effective = effectiveId(parent)
	if effective == skillLineId then
		return nil
	end
	return effective
end

-- What an answer adds to the join: 2 for a parent id, 1 for another id, 0 for nothing.
local function joinRank(parent, skillLineId)
	if joinId(parent, skillLineId) == nil then
		return 0
	end
	return parent.parentId ~= nil and 2 or 1
end

--- The skill-line map this session reads, laid over the one saved account-wide. The lookup may
-- answer only on a character who knows the profession (S1), and the join is for finding
-- *other* characters, so one answer from any character has to outlive its session.
-- A live entry wins unless it adds less to the join than the saved one. So a build that
-- re-parents a line is picked up on the next read, while an alt whose lookup names only the
-- line, or a zeroed struct, never erases a saved parent. A build that drops a parent keeps the
-- saved one, which costs nothing: the direct match still runs. Kept entries carry saved = true.
function Model.MergeSkillLineParents(saved, live)
	local merged = {}
	for skillLineId, parent in pairs(type(saved) == "table" and saved or {}) do
		if type(parent) == "table" then
			local entry = {}
			for field, value in pairs(parent) do
				entry[field] = value
			end
			entry.saved = true
			merged[skillLineId] = entry
		end
	end
	for skillLineId, parent in pairs(type(live) == "table" and live or {}) do
		if type(parent) == "table"
			and joinRank(parent, skillLineId) >= joinRank(merged[skillLineId], skillLineId) then
			merged[skillLineId] = parent
		end
	end
	return merged
end

-- A character's profession matches a challenge's skill line directly, or through the line's
-- effective id -- `parentProfessionID or professionID`, the value Blizzard's own frame compares
-- GetProfessionInfo's skillLine against (Blizzard_ProfessionsFrame.lua:41). Which one the
-- client actually needs is S1; accepting both is what makes the mapper correct either way.
local function matches(profession, skillLineId, parent)
	local id = profession.skillLineId
	if type(id) ~= "number" then
		return false
	end
	if id == skillLineId then
		return true
	end
	local effective = effectiveId(parent)
	return effective ~= nil and id == effective
end

-- Snapshots arrive straight from Store, which never validates: a newer schema's table, or a
-- hand-edited one, can hold anything. Only a keyed snapshot with a professions list joins.
local function professionsOf(snapshot)
	if type(snapshot) ~= "table" or type(snapshot.key) ~= "string" then
		return nil
	end
	if type(snapshot.professions) ~= "table" then
		return nil
	end
	return snapshot.professions
end

--- For each incomplete tradeskill challenge, every stored character with that profession,
-- closest first. `parents` is Api.GetSkillLineParents output and may be nil.
-- Returns a list in the challenges' order:
--   { challenge, skillLineId, need, parentKnown, candidates = { { key, name, class, level,
--     skill, remaining, reached } } }
-- `parentKnown` is false when the skill-line lookup gave no id other than the line's own, so
-- only a direct match can join and an empty list is not proof that nobody has the profession.
-- `reached` means the snapshot's skill already meets the threshold while the challenge still
-- reads incomplete: a stale snapshot, or a credit the client has not given yet.
function Model.ProfessionCandidates(challenges, snapshots, parents)
	local out = {}
	parents = parents or {}

	for _, challenge in ipairs(challenges or {}) do
		local criterion = not challenge.completed and skillCriterion(challenge) or nil
		if criterion then
			local candidates = {}
			for _, snapshot in ipairs(snapshots or {}) do
				for _, profession in ipairs(professionsOf(snapshot) or {}) do
					if type(profession) == "table"
						and matches(profession, criterion.assetId, parents[criterion.assetId])
						and type(profession.skill) == "number" then
						local remaining = criterion.need - profession.skill
						candidates[#candidates + 1] = {
							key = snapshot.key,
							name = snapshot.name,
							class = snapshot.class,
							level = snapshot.level,
							skill = profession.skill,
							remaining = remaining > 0 and remaining or 0,
							reached = remaining <= 0,
						}
						break
					end
				end
			end

			table.sort(candidates, function(a, b)
				if a.remaining ~= b.remaining then
					return a.remaining < b.remaining
				end
				return a.key < b.key
			end)

			out[#out + 1] = {
				challenge = challenge,
				skillLineId = criterion.assetId,
				need = criterion.need,
				parentKnown = joinId(parents[criterion.assetId], criterion.assetId) ~= nil,
				candidates = candidates,
			}
		end
	end

	return out
end

--------------------------------------------------------------------------------------------
-- The roster tab
--------------------------------------------------------------------------------------------

-- Coarse on purpose: the age says how far to trust a snapshot, not when it was taken.
local function ageText(now, at)
	if type(now) ~= "number" or type(at) ~= "number" then
		return nil
	end
	local seconds = now - at
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return ("%dm ago"):format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return ("%dh ago"):format(math.floor(seconds / 3600))
	end
	return ("%dd ago"):format(math.floor(seconds / 86400))
end

-- First UTF-8 character, so a localized tree name never splits mid-byte.
local function initial(name)
	return type(name) == "string" and name:match("^[%z\1-\127\194-\244][\128-\191]*") or nil
end

local function readTrees(row)
	if type(row.trees) ~= "table" or not row.trees[1] then
		return nil
	end
	for _, tree in ipairs(row.trees) do
		if type(tree) ~= "table" or type(tree.spent) ~= "number" then
			return nil
		end
	end
	return row.trees
end

-- Column heading over the per-tree figures: the trees' own initials when every stored tree
-- carries a name, so nothing here names a tree.
local function treeHeading(rows)
	for _, row in ipairs(rows) do
		local trees = readTrees(row)
		if trees then
			local letters = {}
			for _, tree in ipairs(trees) do
				local letter = initial(tree.name)
				if not letter then
					return "Spent"
				end
				letters[#letters + 1] = letter
			end
			return table.concat(letters, "/")
		end
	end
	return "Spent"
end

local function spendText(row)
	local trees = readTrees(row)
	if not trees then
		return "?"
	end
	local parts = {}
	for _, tree in ipairs(trees) do
		parts[#parts + 1] = tostring(tree.spent)
	end
	return table.concat(parts, "/")
end

local function characterName(row, withRealm)
	local name = (withRealm or type(row.name) ~= "string") and row.key or row.name
	local text = name .. "  L" .. (type(row.level) == "number" and tostring(row.level) or "?")
	if type(row.class) == "string" and row.class ~= "" then
		text = text .. " " .. row.class
	end
	return text
end

-- A part MergeSnapshot kept from an earlier snapshot carries its own, older timestamp.
local function keptLine(lines, row, part, label, now)
	local at = row[part .. "At"]
	if type(at) ~= "number" or at == row.takenAt then
		return
	end
	local reason = row[part .. "Reason"]
	lines[#lines + 1] = label .. " from " .. (ageText(now, at) or "an earlier session")
		.. (reason and (": " .. tostring(reason)) or "")
end

local function characterDetail(row, now)
	local lines = {}

	local trees = readTrees(row)
	if trees then
		local parts = {}
		for _, tree in ipairs(trees) do
			parts[#parts + 1] = tostring(tree.name or tree.treeId) .. " " .. tostring(tree.spent)
		end
		lines[#lines + 1] = "Spent: " .. table.concat(parts, ", ")
		if type(row.unspent) == "number" then
			lines[#lines + 1] = "Unspent: " .. tostring(row.unspent)
				.. (type(row.cap) == "number" and (" of " .. tostring(row.cap)) or "")
		end
	else
		lines[#lines + 1] = "Tree spend not read"
			.. (row.treesReason and (": " .. tostring(row.treesReason)) or "")
	end
	keptLine(lines, row, "trees", "Trees", now)

	if type(row.professions) == "table" then
		if row.professions[1] == nil then
			lines[#lines + 1] = "No professions"
		end
		for _, profession in ipairs(row.professions) do
			if type(profession) == "table" then
				lines[#lines + 1] = tostring(profession.name or profession.skillLineId) .. " "
					.. tostring(profession.skill) .. "/" .. tostring(profession.max)
			end
		end
	else
		lines[#lines + 1] = "Professions not read"
			.. (row.professionsReason and (": " .. tostring(row.professionsReason)) or "")
	end
	keptLine(lines, row, "professions", "Professions", now)

	local age = ageText(now, row.takenAt)
	if age then
		lines[#lines + 1] = "Updated " .. age
	end
	return lines
end

local function realmCount(rows)
	local seen, count = {}, 0
	for _, row in ipairs(rows) do
		if type(row.realm) == "string" and not seen[row.realm] then
			seen[row.realm] = true
			count = count + 1
		end
	end
	return count
end

-- Tradeskill challenges some saved character can work on, closest first, then client order.
-- The rest are counted, not listed: a row that says "nobody" eighteen times is noise.
local function tradeskillRows(candidates)
	local shown, hidden, unjoined = {}, 0, 0
	for index, entry in ipairs(candidates) do
		if type(entry) == "table" and type(entry.challenge) == "table"
			and type(entry.candidates) == "table" and entry.candidates[1] then
			shown[#shown + 1] = { entry = entry, index = index }
		else
			hidden = hidden + 1
			if type(entry) == "table" and entry.parentKnown == false then
				unjoined = unjoined + 1
			end
		end
	end
	table.sort(shown, function(a, b)
		local aLeft, bLeft = a.entry.candidates[1].remaining, b.entry.candidates[1].remaining
		if aLeft ~= bLeft then
			return aLeft < bLeft
		end
		return a.index < b.index
	end)

	local rows = {}
	for _, item in ipairs(shown) do
		local entry, challenge = item.entry, item.entry.challenge
		local best = entry.candidates[1]
		local detail = {}
		if type(challenge.description) == "string" and challenge.description ~= "" then
			detail[#detail + 1] = challenge.description
		end
		for _, candidate in ipairs(entry.candidates) do
			detail[#detail + 1] = Model.CandidateLine(candidate, entry.need)
		end
		rows[#rows + 1] = {
			kind = "tradeskill",
			id = challenge.id,
			name = tostring(challenge.name or ("Challenge " .. tostring(challenge.id))) .. Model.SEPARATOR
				.. tostring(best.name or best.key),
			category = challenge.categoryName,
			progressText = tostring(best.skill) .. "/" .. tostring(entry.need),
			pointsText = Model.PointsText(challenge.points),
			measurable = true,
			detail = detail,
		}
	end
	return rows, hidden, unjoined
end

local function plural(count, one, many)
	return tostring(count) .. " " .. (count == 1 and one or many)
end

--- The roster tab's view, in the same shape Model.BuildView returns so one renderer draws both.
-- input = { snapshots, currentKey, now, candidates = Model.ProfessionCandidates output,
-- challengesReason, rewardTrack, rewardTrackReason, error }
function Model.BuildRosterView(input)
	input = input or {}
	local view = {
		tab = "roster",
		header = Model.Header(input.rewardTrack, input.rewardTrackReason),
		filters = {},
		rows = {},
		state = "ok",
	}

	if input.error ~= nil or type(input.snapshots) ~= "table" then
		view.state = "error"
		view.message = "Could not read the roster"
			.. (input.error ~= nil and (": " .. tostring(input.error)) or "")
		return view
	end

	local notes = {}
	local roster = Model.Roster(input.snapshots, input.currentKey)
	if roster.skipped > 0 then
		notes[#notes + 1] = plural(roster.skipped, "saved character", "saved characters") .. " could not be read"
	end

	if not roster.rows[1] then
		view.state = "empty"
		view.message = "No characters saved yet. Each character joins the roster when it logs in."
	else
		view.rows[1] = { kind = "columns", name = "Character", progressText = treeHeading(roster.rows),
			pointsText = "Free" }
		local withRealm = realmCount(roster.rows) > 1
		for _, row in ipairs(roster.rows) do
			view.rows[#view.rows + 1] = {
				kind = "character",
				key = row.key,
				name = characterName(row, withRealm),
				category = type(row.realm) == "string" and row.realm or nil,
				progressText = spendText(row),
				pointsText = type(row.unspent) == "number" and tostring(row.unspent) or "?",
				measurable = true,
				current = row.key == roster.currentKey,
				detail = characterDetail(row, input.now),
			}
		end
	end

	if input.challengesReason then
		notes[#notes + 1] = "Could not read tradeskill challenges: " .. tostring(input.challengesReason)
	elseif type(input.candidates) == "table" then
		local rows, hidden, unjoined = tradeskillRows(input.candidates)
		if rows[1] then
			view.rows[#view.rows + 1] = { kind = "columns", name = "Tradeskill challenge", progressText = "Skill",
				pointsText = "" }
			for _, row in ipairs(rows) do
				view.rows[#view.rows + 1] = row
			end
		end
		if hidden > 0 then
			local note = plural(hidden, "tradeskill challenge has", "tradeskill challenges have")
				.. " no saved character with the profession"
			if unjoined > 0 then
				note = note .. ". The profession lookup gave no answer for " .. tostring(unjoined)
					.. " of them, so a match may be missing"
			end
			notes[#notes + 1] = note
		end
	end

	if notes[1] then
		view.footnote = table.concat(notes, "\n")
	end
	return view
end
