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

local function snapshotTrees(treeSpend)
	local trees = {}
	for _, treeId in ipairs(treeSpend.treeIds or {}) do
		local tree = treeSpend[treeId]
		if type(tree) == "table" then
			trees[#trees + 1] = { treeId = treeId, name = tree.name, spent = tree.spentInTree }
		end
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

	if type(character.professions) == "table" then
		snapshot.professions = snapshotProfessions(character.professions)
		snapshot.professionsAt = input.now
	else
		snapshot.professionsReason = character.professionsReason or "not read"
	end

	local spend = input.treeSpend
	if type(spend) == "table" then
		snapshot.trees = snapshotTrees(spend)
		snapshot.spent = spend.spent
		snapshot.unspent = spend.unspent
		snapshot.cap = spend.cap
		snapshot.treesAt = input.now
	else
		snapshot.treesReason = input.treeSpendReason or "not read"
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

	if fresh.professions == nil and previous.professions ~= nil then
		merged.professions = previous.professions
		merged.professionsAt = previous.professionsAt
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

-- A character's profession matches a challenge's skill line directly, or through the line's
-- parent. Which of the two the client actually needs is S1; accepting both is what makes the
-- mapper correct either way.
local function matches(profession, skillLineId, parent)
	local id = profession.skillLineId
	if type(id) ~= "number" then
		return false
	end
	if id == skillLineId then
		return true
	end
	return parent ~= nil and parent.parentId ~= nil and id == parent.parentId
end

--- For each incomplete tradeskill challenge, every stored character with that profession,
-- closest first. `parents` is Api.GetSkillLineParents output and may be nil.
-- Returns a list in the challenges' order:
--   { challenge, skillLineId, need, candidates = { { key, name, class, level, skill,
--     remaining, reached } } }
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
				for _, profession in ipairs(type(snapshot) == "table" and snapshot.professions or {}) do
					if matches(profession, criterion.assetId, parents[criterion.assetId])
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
				candidates = candidates,
			}
		end
	end

	return out
end
