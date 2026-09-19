local _, ns = ...

-- The only layer permitted to call WoW globals. Every read feature-detects the function,
-- wraps the call in pcall, guards the result with issecretvalue when that exists, and
-- returns plain Lua tables or nil plus a reason. No UI code lives here.
ns.Api = ns.Api or {}
local Api = ns.Api

-- Questions docs/legacy-internals.md could not close. Both default off; turning one on is a
-- deliberate act that needs a captured fixture behind it first.
Api.flags = {
	-- Q12: no Legacy addon registers TRAIT_* or MAJOR_FACTION_* events, and whether they fire
	-- on Forever is unconfirmed. Until in-game item C2 comes back, Api is read-on-demand only.
	eventDrivenRefresh = false,
	-- Q4: criteriaType 8 chains run hundreds of achievements deep. Api reports assetId and
	-- stops. Recursing here would multiply every sweep by that depth before Model has decided
	-- whether it wants the answer at all.
	followMetaChains = false,
}

-- Fallbacks only. Constants.LegacyConsts is read first and is the source of truth; these exist
-- so a dump still works if that table moves. Verified in game 2026-09-18, build 1.60.1.
local CONSTANT_FALLBACK = {
	LEGACY_REWARD_TRACK_FACTION_ID = 2802,
	LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225,
	LEGACY_TREE_PROFESSIONS_ID = 1187,
	LEGACY_TREE_ADVENTURE_ID = 1188,
	LEGACY_TREE_PROGRESSION_ID = 1189,
}

-- Tree display names are client global strings, so they are read by name like everything else.
-- The constant, the atlas and the display string disagree on tree 1189 ("Progression" versus
-- "Resourcefulness"), which is why the mapping is spelled out rather than derived.
local TREE_NAME_GLOBAL = {
	LEGACY_TREE_PROFESSIONS_ID = "LEGACY_TREE_PROFESSIONS",
	LEGACY_TREE_ADVENTURE_ID = "LEGACY_TREE_ADVENTURE",
	LEGACY_TREE_PROGRESSION_ID = "LEGACY_TREE_PROGRESSION",
}

local TREE_CONSTANTS = {
	"LEGACY_TREE_PROFESSIONS_ID",
	"LEGACY_TREE_ADVENTURE_ID",
	"LEGACY_TREE_PROGRESSION_ID",
}

-- Neither flag mask is defined in the pinned Blizzard source, so both are feature-detected
-- from the client and fall back to the value verified in game.
local FLAG_FALLBACK = {
	ACHIEVEMENT_FLAGS_ACCOUNT = 131072,
	EVALUATION_TREE_FLAG_PROGRESS_BAR = 1,
}

local MAX_COPY_DEPTH = 6

--------------------------------------------------------------------------------------------
-- Failure tally
--------------------------------------------------------------------------------------------

local stats = {}

local function record(name, outcome, detail)
	local entry = stats[name]
	if not entry then
		entry = { calls = 0, ok = 0, missing = 0, errors = 0, secret = 0 }
		stats[name] = entry
	end

	entry.calls = entry.calls + 1
	entry[outcome] = (entry[outcome] or 0) + 1
	if detail then
		entry.lastDetail = detail
	end

	return entry
end

-- A snapshot, so callers cannot mutate the tally by holding onto it.
function Api.GetFailures()
	local out = {}
	for name, entry in pairs(stats) do
		out[name] = {
			calls = entry.calls,
			ok = entry.ok,
			missing = entry.missing,
			errors = entry.errors,
			secret = entry.secret,
			lastDetail = entry.lastDetail,
		}
	end
	return out
end

function Api.ResetFailures()
	stats = {}
end

--------------------------------------------------------------------------------------------
-- Guards
--------------------------------------------------------------------------------------------

local function pack(...)
	return { n = select("#", ...), ... }
end

-- Midnight's secret values. The guard is itself feature-detected: issecretvalue does not exist
-- on every client this addon might load on, and its absence is not an error.
local function isSecret(value)
	local check = rawget(_G, "issecretvalue")
	if type(check) ~= "function" then
		return false
	end

	local ok, secret = pcall(check, value)
	return ok and secret == true
end

Api.IsSecret = isSecret

-- Resolves a dotted global path without ever indexing a missing namespace.
local function resolve(path)
	local current = nil
	for segment in string.gmatch(path, "[^%.]+") do
		if current == nil then
			current = rawget(_G, segment)
		elseif type(current) == "table" then
			current = rawget(current, segment)
		else
			return nil
		end

		if current == nil then
			return nil
		end
	end
	return current
end

Api.Resolve = resolve

-- Api hands out plain tables it owns, never a client-owned one: the client may reuse or mutate
-- its tables, and a secret can sit in a field while the table itself reads non-secret.
local function plainCopy(value, depth, seen)
	if isSecret(value) then
		return nil, "secret"
	end

	local kind = type(value)
	if kind ~= "table" then
		if kind == "function" or kind == "userdata" or kind == "thread" then
			return nil, "unsupported type " .. kind
		end
		return value
	end

	if depth > MAX_COPY_DEPTH then
		return nil, "deeper than " .. MAX_COPY_DEPTH
	end
	if seen[value] then
		return nil, "cyclic"
	end
	seen[value] = true

	local out = {}
	for key, item in pairs(value) do
		local copiedKey, keyReason = plainCopy(key, depth + 1, seen)
		if copiedKey == nil then
			seen[value] = nil
			return nil, keyReason or "bad key"
		end

		local copiedItem, itemReason = plainCopy(item, depth + 1, seen)
		if copiedItem == nil then
			seen[value] = nil
			return nil, itemReason or "bad value"
		end

		out[copiedKey] = copiedItem
	end

	seen[value] = nil
	return out
end

function Api.PlainCopy(value)
	return plainCopy(value, 1, {})
end

-- Every WoW global call in the addon goes through here. Returns a packed result table with an
-- `n` field, or nil plus a reason. Packed rather than varargs so "the function returned nil"
-- and "the call failed" stay distinguishable at the call site.
local function call(path, ...)
	local fn = resolve(path)
	if type(fn) ~= "function" then
		record(path, "missing")
		return nil, "missing"
	end

	local raw = pack(pcall(fn, ...))
	if not raw[1] then
		local detail = tostring(raw[2])
		record(path, "errors", detail)
		return nil, "error: " .. detail
	end

	local out = { n = raw.n - 1 }
	for index = 2, raw.n do
		local value = raw[index]
		if type(value) == "table" then
			local copied, reason = plainCopy(value, 1, {})
			if copied == nil then
				record(path, "secret", reason)
				return nil, reason
			end
			value = copied
		elseif isSecret(value) then
			record(path, "secret")
			return nil, "secret"
		end
		out[index - 1] = value
	end

	record(path, "ok")
	return out
end

Api.Call = call

-- Single-bit masks only, which is all the Legacy surface uses. Written without `bit` so the
-- guard layer stays loadable under plain Lua 5.1 for tests.
local function hasFlag(value, mask)
	if type(value) ~= "number" or type(mask) ~= "number" or mask <= 0 then
		return false
	end
	return value % (mask + mask) >= mask
end

Api.HasFlag = hasFlag

--------------------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------------------

-- Returns the value and where it came from, so a dump shows when we are running on fallbacks.
function Api.GetConstant(name)
	local consts = resolve("Constants.LegacyConsts")
	if type(consts) == "table" then
		local value = rawget(consts, name)
		if type(value) == "number" and not isSecret(value) then
			record("Constants.LegacyConsts." .. name, "ok")
			return value, "runtime"
		end
	end

	record("Constants.LegacyConsts." .. name, "missing")
	local fallback = CONSTANT_FALLBACK[name]
	if fallback then
		return fallback, "fallback"
	end
	return nil, "unknown constant"
end

local function globalNumber(name)
	local value = rawget(_G, name)
	if type(value) == "number" and not isSecret(value) then
		record(name, "ok")
		return value, "runtime"
	end

	record(name, "missing")
	return FLAG_FALLBACK[name], "fallback"
end

local function globalString(name)
	local value = rawget(_G, name)
	if type(value) == "string" and not isSecret(value) then
		record(name, "ok")
		return value
	end

	record(name, "missing")
	return nil
end

--------------------------------------------------------------------------------------------
-- Challenges
--------------------------------------------------------------------------------------------

local function readCriteria(achievementId, progressBarMask)
	local countResult = call("GetAchievementNumCriteria", achievementId)
	if not countResult then
		return nil
	end

	local count = countResult[1]
	if type(count) ~= "number" or count <= 0 then
		-- Not an error. 34 of the 111 challenges genuinely have no criteria and are binary;
		-- an empty list here is the honest answer and Model has to handle it as its own case.
		return {}
	end

	local criteria = {}
	for index = 1, count do
		local result = call("GetAchievementCriteriaInfo", achievementId, index)
		if result then
			local flags = result[7]
			criteria[#criteria + 1] = {
				index = index,
				text = result[1],
				criteriaType = result[2],
				completed = result[3] and true or false,
				have = result[4],
				need = result[5],
				charName = result[6],
				flags = flags,
				assetId = result[8],
				quantityString = result[9],
				isProgressBar = hasFlag(flags, progressBarMask),
			}
		end
	end

	return criteria
end

-- Walks the category list directly. Never SetAchievementSearchString: that is global client
-- state shared with Blizzard's Achievement UI and it changes underneath us.
function Api.GetChallenges()
	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")
	local accountMask = globalNumber("ACHIEVEMENT_FLAGS_ACCOUNT")
	local progressBarMask = globalNumber("EVALUATION_TREE_FLAG_PROGRESS_BAR")

	local categoriesResult = call("GetCategoryList")
	if not categoriesResult then
		return nil, "GetCategoryList unavailable"
	end

	local categories = categoriesResult[1]
	if type(categories) ~= "table" then
		return nil, "GetCategoryList returned no list"
	end

	local challenges = {}
	for _, categoryId in ipairs(categories) do
		local countResult = call("GetCategoryNumAchievements", categoryId)
		local total = countResult and countResult[1]

		-- Drop empty categories by count, never by name: "Do Not Display" is a real category
		-- the client hands back and its name is not a contract.
		if type(total) == "number" and total > 0 then
			local infoResult = call("GetCategoryInfo", categoryId)
			local categoryName = infoResult and infoResult[1]
			local parentId = infoResult and infoResult[2]

			for index = 1, total do
				local result = call("GetAchievementInfo", categoryId, index)
				local achievementId = result and result[1]

				if type(achievementId) == "number" then
					local flags = result[9]
					local points
					if currencyId then
						local pointsResult =
							call("C_Traits.GetTraitCurrencyForAchievement", currencyId, achievementId)
						points = pointsResult and pointsResult[1]
					end

					challenges[#challenges + 1] = {
						id = achievementId,
						name = result[2],
						categoryId = categoryId,
						categoryName = categoryName,
						parentCategoryId = parentId,
						categoryIndex = index,
						points = points,
						-- `completed` is account state. Per-character "done" is
						-- completed and wasEarnedByMe, which is Model's call to make.
						completed = result[4] and true or false,
						wasEarnedByMe = result[13] and true or false,
						earnedBy = result[14],
						description = result[8],
						rewardText = result[11],
						icon = result[10],
						flags = flags,
						isAccountWide = hasFlag(flags, accountMask),
						criteria = readCriteria(achievementId, progressBarMask),
					}
				end
			end
		end
	end

	if #challenges == 0 then
		return nil, "no challenges enumerated"
	end

	return challenges
end

--------------------------------------------------------------------------------------------
-- Reward track
--------------------------------------------------------------------------------------------

local function readRewards(factionId, level)
	local result = call("C_MajorFactions.GetRenownRewardsForLevel", factionId, level)
	local list = result and result[1]
	if type(list) ~= "table" then
		return nil
	end

	local rewards = {}
	for _, entry in ipairs(list) do
		rewards[#rewards + 1] = {
			-- `name` is absent on some entries and toastDescription is not, so the fallback
			-- is normal rather than an error path.
			name = entry.name or entry.toastDescription,
			rawName = entry.name,
			toastDescription = entry.toastDescription,
			description = entry.description,
			icon = entry.icon,
			itemID = entry.itemID,
			spellID = entry.spellID,
			mountID = entry.mountID,
			titleMaskID = entry.titleMaskID,
			rewardType = entry.rewardType,
			-- Account collection state, not "this threshold is reached". Read true at a
			-- threshold a renown-0 character had not hit. Never render it as progress.
			isCollected = entry.isCollected,
			isAccountUnlock = entry.isAccountUnlock,
			uiOrder = entry.uiOrder,
		}
	end

	return rewards
end

function Api.GetRewardTrack()
	local factionId = Api.GetConstant("LEGACY_REWARD_TRACK_FACTION_ID")
	if not factionId then
		return nil, "no faction id"
	end

	local dataResult = call("C_MajorFactions.GetMajorFactionData", factionId)
	local data = dataResult and dataResult[1]
	if type(data) ~= "table" then
		return nil, "GetMajorFactionData unavailable"
	end

	local levelResult = call("C_MajorFactions.GetCurrentRenownLevel", factionId)
	local level = levelResult and levelResult[1] or data.renownLevel

	local hiddenResult = call("C_MajorFactions.IsMajorFactionHiddenFromExpansionPage", factionId)

	local track = {
		factionId = factionId,
		name = data.name,
		-- The renown level of faction 2802 *is* the account's earned Legacy point count.
		-- Two names for one client number, kept because both readings are used downstream.
		level = level,
		earned = level,
		maxLevel = data.maxLevel,
		isUnlocked = data.isUnlocked and true or false,
		isHidden = hiddenResult and hiddenResult[1] and true or false,
		thresholds = {},
	}

	local levelsResult = call("C_MajorFactions.GetRenownLevels", factionId)
	local levels = levelsResult and levelsResult[1]
	if type(levels) ~= "table" then
		return track, "GetRenownLevels unavailable"
	end

	-- The list is sparse: four reward thresholds, not one entry per level. Sorted defensively
	-- because every calculation below assumes ascending order.
	local thresholds = {}
	for _, info in ipairs(levels) do
		if type(info.level) == "number" then
			thresholds[#thresholds + 1] = {
				level = info.level,
				locked = info.locked,
				isMilestone = info.isMilestone,
				isCapstone = info.isCapstone,
			}
		end
	end
	table.sort(thresholds, function(a, b) return a.level < b.level end)

	local reached = 0
	for _, threshold in ipairs(thresholds) do
		threshold.reached = type(level) == "number" and level >= threshold.level
		if threshold.reached then
			reached = reached + 1
		end
		threshold.rewards = readRewards(factionId, threshold.level)

		if not threshold.reached and not track.nextThreshold then
			track.nextThreshold = threshold.level
			track.nextRewards = threshold.rewards
			if type(level) == "number" then
				track.pointsToNext = threshold.level - level
			end
		end
	end

	track.thresholds = thresholds
	track.thresholdsReached = reached

	return track
end

--------------------------------------------------------------------------------------------
-- Trees and points
--------------------------------------------------------------------------------------------

function Api.GetTreeSpend()
	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")

	local spend = {
		currencyId = currencyId,
		-- The cap comes from GetMaxAvailableTraitCurrency, never from TreeCurrencyInfo's
		-- maxQuantity, which read 0 on a character at zero points. Q7 is still open on what
		-- maxQuantity actually tracks, so it is reported raw per tree and used for nothing.
		capSource = "C_Traits.GetMaxAvailableTraitCurrency",
		treeIds = {},
	}

	if currencyId then
		local capResult = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true)
		spend.cap = capResult and capResult[1]

		local earnableResult = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, false)
		spend.earnable = earnableResult and earnableResult[1]
	end

	for _, constantName in ipairs(TREE_CONSTANTS) do
		local treeId = Api.GetConstant(constantName)
		if treeId then
			spend.treeIds[#spend.treeIds + 1] = treeId

			local tree = {
				treeId = treeId,
				constant = constantName,
				name = globalString(TREE_NAME_GLOBAL[constantName]),
			}

			-- Documented MayReturnNothing. A fresh character does have a config, but guard it.
			local configResult = call("C_Traits.GetConfigIDByTreeID", treeId)
			local configId = configResult and configResult[1]
			tree.configId = configId

			if configId then
				local stagedResult = call("C_Traits.ConfigHasStagedChanges", configId)
				tree.hasStagedChanges = stagedResult and stagedResult[1] and true or false

				local currencyResult = call("C_Traits.GetTreeCurrencyInfo", configId, treeId, true)
				local list = currencyResult and currencyResult[1]
				local info = type(list) == "table" and list[1] or nil
				if info then
					tree.traitCurrencyId = info.traitCurrencyID
					tree.quantity = info.quantity
					tree.spent = info.spent
					tree.spentInTree = info.spentInTree
					tree.maxQuantity = info.maxQuantity

					-- All three trees share one configID and one currency, so unspent and
					-- total spent are pool-wide numbers; only spentInTree differs.
					if spend.unspent == nil then
						spend.unspent = info.quantity
					end
					if spend.spent == nil then
						spend.spent = info.spent
					end
				end
			end

			spend[treeId] = tree
		end
	end

	if #spend.treeIds == 0 then
		return nil, "no tree constants"
	end

	return spend
end

--------------------------------------------------------------------------------------------
-- Character
--------------------------------------------------------------------------------------------

local function readProfessions()
	-- Verified on the forever branch: Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua
	-- destructures seven returns (two primary, five secondary) where Mainline uses six with
	-- different meanings. Slots are never named here, only iterated.
	local result = call("GetProfessions")
	if not result then
		return nil, "GetProfessions unavailable"
	end

	local professions = {}
	for slot = 1, result.n do
		local skillIndex = result[slot]
		if type(skillIndex) == "number" then
			local info = call("GetProfessionInfo", skillIndex)
			if info then
				professions[#professions + 1] = {
					slot = slot,
					skillIndex = skillIndex,
					name = info[1],
					icon = info[2],
					skill = info[3],
					max = info[4],
					skillLineId = info[7],
					modifier = info[8],
					skillLineName = info[11],
				}
			end
		end
	end

	return professions
end

function Api.GetCharacterInfo()
	local classResult = call("UnitClass", "player")
	local levelResult = call("UnitLevel", "player")
	local nameResult = call("UnitName", "player")
	local realmResult = call("GetRealmName")

	if not classResult and not levelResult then
		return nil, "unit API unavailable"
	end

	local professions, professionsReason = readProfessions()

	return {
		name = nameResult and nameResult[1],
		realm = realmResult and realmResult[1],
		class = classResult and classResult[1],
		classToken = classResult and classResult[2],
		classId = classResult and classResult[3],
		level = levelResult and levelResult[1],
		professions = professions,
		professionsReason = professionsReason,
	}
end

--------------------------------------------------------------------------------------------
-- Probe
--------------------------------------------------------------------------------------------

local function status(path, ...)
	local result, reason = call(path, ...)
	if not result then
		if reason == "missing" then
			return { name = path, status = "missing" }
		end
		if reason == "secret" then
			return { name = path, status = "secret" }
		end
		return { name = path, status = "error", detail = reason }
	end

	if result.n == 0 or result[1] == nil then
		return { name = path, status = "nil" }
	end

	-- A table address tells nobody anything and changes every run, so report its size instead.
	local first = result[1]
	local detail
	if type(first) == "table" then
		local count = 0
		for _ in pairs(first) do count = count + 1 end
		detail = "table, " .. count .. " entries"
	else
		detail = tostring(first)
	end

	return { name = path, status = "ok", detail = detail }
end

local function skipped(path, why)
	return { name = path, status = "skipped", detail = why }
end

-- One line per API we depend on, in dependency order: later probes reuse IDs the earlier ones
-- discovered, so a failure near the top explains the skips below it.
function Api.Probe()
	local rows = {}
	local function add(row) rows[#rows + 1] = row end

	local secretGuard = resolve("issecretvalue")
	add({
		name = "issecretvalue",
		status = type(secretGuard) == "function" and "ok" or "missing",
		detail = type(secretGuard) == "function" and "guard active" or "guard inert",
	})

	for name in pairs(CONSTANT_FALLBACK) do
		local value, source = Api.GetConstant(name)
		add({
			name = "Constants.LegacyConsts." .. name,
			status = source == "runtime" and "ok" or "missing",
			detail = tostring(value) .. " (" .. source .. ")",
		})
	end

	for name in pairs(FLAG_FALLBACK) do
		local value, source = globalNumber(name)
		add({
			name = name,
			status = source == "runtime" and "ok" or "missing",
			detail = tostring(value) .. " (" .. source .. ")",
		})
	end

	add(status("GetBuildInfo"))
	add(status("UnitClass", "player"))
	add(status("UnitLevel", "player"))

	local professionsResult = call("GetProfessions")
	add(status("GetProfessions"))
	local professionIndex
	if professionsResult then
		for slot = 1, professionsResult.n do
			if type(professionsResult[slot]) == "number" then
				professionIndex = professionsResult[slot]
				break
			end
		end
	end
	if professionIndex then
		add(status("GetProfessionInfo", professionIndex))
	else
		add(skipped("GetProfessionInfo", "character knows no professions"))
	end

	local categoriesResult = call("GetCategoryList")
	add(status("GetCategoryList"))

	local categories = categoriesResult and categoriesResult[1]
	local sampleCategory, sampleAchievement, criteriaAchievement
	if type(categories) == "table" then
		for _, categoryId in ipairs(categories) do
			local countResult = call("GetCategoryNumAchievements", categoryId)
			local total = countResult and countResult[1]
			if type(total) == "number" and total > 0 then
				sampleCategory = sampleCategory or categoryId
				for index = 1, total do
					local info = call("GetAchievementInfo", categoryId, index)
					local achievementId = info and info[1]
					if type(achievementId) == "number" then
						sampleAchievement = sampleAchievement or achievementId
						if not criteriaAchievement then
							local countCriteria = call("GetAchievementNumCriteria", achievementId)
							local n = countCriteria and countCriteria[1]
							if type(n) == "number" and n > 0 then
								criteriaAchievement = achievementId
							end
						end
					end
					if criteriaAchievement then
						break
					end
				end
			end
			if criteriaAchievement then
				break
			end
		end
	end

	if sampleCategory then
		add(status("GetCategoryInfo", sampleCategory))
		add(status("GetCategoryNumAchievements", sampleCategory))
		add(status("GetAchievementInfo", sampleCategory, 1))
	else
		add(skipped("GetCategoryInfo", "no category with achievements"))
		add(skipped("GetCategoryNumAchievements", "no category with achievements"))
		add(skipped("GetAchievementInfo", "no category with achievements"))
	end

	if sampleAchievement then
		add(status("GetAchievementNumCriteria", sampleAchievement))
		add(status("GetAchievementCategory", sampleAchievement))
		add(status("C_AchievementInfo.IsValidAchievement", sampleAchievement))
	else
		add(skipped("GetAchievementNumCriteria", "no achievement found"))
		add(skipped("GetAchievementCategory", "no achievement found"))
		add(skipped("C_AchievementInfo.IsValidAchievement", "no achievement found"))
	end

	if criteriaAchievement then
		add(status("GetAchievementCriteriaInfo", criteriaAchievement, 1))
	else
		add(skipped("GetAchievementCriteriaInfo", "no achievement with criteria"))
	end

	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")
	if currencyId and sampleAchievement then
		add(status("C_Traits.GetTraitCurrencyForAchievement", currencyId, sampleAchievement))
	else
		add(skipped("C_Traits.GetTraitCurrencyForAchievement", "no currency or achievement"))
	end

	if currencyId then
		add(status("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true))
	else
		add(skipped("C_Traits.GetMaxAvailableTraitCurrency", "no currency id"))
	end

	local treeId = Api.GetConstant("LEGACY_TREE_PROFESSIONS_ID")
	local configResult = treeId and call("C_Traits.GetConfigIDByTreeID", treeId)
	if treeId then
		add(status("C_Traits.GetConfigIDByTreeID", treeId))
	else
		add(skipped("C_Traits.GetConfigIDByTreeID", "no tree id"))
	end

	local configId = configResult and configResult[1]
	if configId and treeId then
		add(status("C_Traits.GetTreeCurrencyInfo", configId, treeId, true))
		add(status("C_Traits.ConfigHasStagedChanges", configId))
	else
		add(skipped("C_Traits.GetTreeCurrencyInfo", "no config id"))
		add(skipped("C_Traits.ConfigHasStagedChanges", "no config id"))
	end

	local factionId = Api.GetConstant("LEGACY_REWARD_TRACK_FACTION_ID")
	if factionId then
		add(status("C_MajorFactions.GetMajorFactionData", factionId))
		add(status("C_MajorFactions.GetCurrentRenownLevel", factionId))
		add(status("C_MajorFactions.IsMajorFactionHiddenFromExpansionPage", factionId))

		local levelsResult = call("C_MajorFactions.GetRenownLevels", factionId)
		add(status("C_MajorFactions.GetRenownLevels", factionId))

		local levels = levelsResult and levelsResult[1]
		local firstLevel = type(levels) == "table" and levels[1] and levels[1].level
		if firstLevel then
			add(status("C_MajorFactions.GetRenownRewardsForLevel", factionId, firstLevel))
		else
			add(skipped("C_MajorFactions.GetRenownRewardsForLevel", "no reward thresholds"))
		end
	else
		add(skipped("C_MajorFactions.GetMajorFactionData", "no faction id"))
	end

	return rows
end
