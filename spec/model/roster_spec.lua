-- Model/Roster.lua under the same strict environment as Model.lua: any global outside the Lua
-- 5.1 standard library is an error at call time.
local STDLIB = {
	"assert", "error", "ipairs", "pairs", "next", "select", "tonumber", "tostring", "type",
	"unpack", "setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "pcall", "xpcall",
	"string", "table", "math",
}

local function strictEnv()
	local env = {}
	for _, name in ipairs(STDLIB) do
		env[name] = _G[name]
	end
	return setmetatable(env, {
		__index = function(_, key)
			error("Model touched a global outside the Lua standard library: " .. tostring(key), 2)
		end,
		__newindex = function(_, key)
			error("Model wrote a global: " .. tostring(key), 2)
		end,
	})
end

local function loadModel()
	local ns = {}
	for _, path in ipairs({ "LegacyNext/Model/Model.lua", "LegacyNext/Model/Roster.lua" }) do
		local chunk = assert(loadfile(path))
		setfenv(chunk, strictEnv())
		chunk("LegacyNext", ns)
	end
	return ns.Model
end

local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

local function byName(list, name)
	for _, item in ipairs(list) do
		if (item.challenge and item.challenge.name or item.name) == name then
			return item
		end
	end
	error("no entry named " .. name)
end

-- No captured character knows a profession yet (D4), so profession records below are Model's
-- own snapshot shape with derived values, never a client capture. 171 stands in for "whatever
-- GetProfessionInfo reports"; which number it really is, is S1.
local function alt(key, level, professions)
	return { key = key, name = key, class = "Druid", level = level, professions = professions }
end

describe("Roster model", function()
	local Model

	before_each(function()
		Model = loadModel()
	end)

	describe("CharacterKey", function()
		it("joins name and realm from the captured character", function()
			local character = fixture("dump_character_shaman").character

			assert.equals("Bong Wrip-Classic Beta PvP", Model.CharacterKey(character))
		end)

		it("refuses a character with no realm rather than keying on name alone", function()
			local key, reason = Model.CharacterKey({ name = "Bong" })

			assert.is_nil(key)
			assert.equals("no realm", reason)
		end)
	end)

	describe("BuildSnapshot", function()
		it("snapshots the captured fresh character and trees", function()
			local snapshot = Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character,
				treeSpend = fixture("dump_trees_fresh").treeSpend,
				now = 1000,
			})

			assert.equals("Bong Wrip-Classic Beta PvP", snapshot.key)
			assert.equals("Shaman", snapshot.class)
			assert.equals(1, snapshot.level)
			-- Empty, not nil: the read worked and the character knows none.
			assert.same({}, snapshot.professions)
			assert.equals(1000, snapshot.professionsAt)
			assert.equals(3, #snapshot.trees)
			assert.same({ treeId = 1187, name = "Professions", spent = 0 }, snapshot.trees[1])
			assert.equals("Resourcefulness", snapshot.trees[3].name)
			assert.equals(0, snapshot.spent)
			assert.equals(0, snapshot.unspent)
			assert.equals(16, snapshot.cap)
			assert.equals(1000, snapshot.treesAt)
		end)

		it("keeps a failed part nil with its reason", function()
			local character = fixture("dump_character_shaman").character
			character.professions = nil
			character.professionsReason = "GetProfessions unavailable"

			local snapshot = Model.BuildSnapshot({
				character = character,
				treeSpendReason = "no tree constants",
				now = 1000,
			})

			assert.is_nil(snapshot.professions)
			assert.equals("GetProfessions unavailable", snapshot.professionsReason)
			assert.is_nil(snapshot.trees)
			assert.equals("no tree constants", snapshot.treesReason)
		end)

		it("returns nil and a reason without a key", function()
			local snapshot, reason = Model.BuildSnapshot({ character = { realm = "R" } })

			assert.is_nil(snapshot)
			assert.equals("no name", reason)
		end)
	end)

	describe("MergeSnapshot", function()
		local function captured(now)
			return Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character,
				treeSpend = fixture("dump_trees_fresh").treeSpend,
				now = now,
			})
		end

		it("keeps the last good trees and professions when the fresh read failed", function()
			local previous = captured(1000)
			local character = fixture("dump_character_shaman").character
			character.professions = nil
			character.level = 2 -- derived: captured 1, varied
			local fresh = Model.BuildSnapshot({ character = character, now = 2000 })

			local merged = Model.MergeSnapshot(previous, fresh)

			assert.equals(2, merged.level)
			assert.equals(2000, merged.takenAt)
			assert.same(previous.trees, merged.trees)
			assert.equals(1000, merged.treesAt)
			assert.equals(16, merged.cap)
			assert.same({}, merged.professions)
			assert.equals(1000, merged.professionsAt)
		end)

		-- The shape Api.GetTreeSpend returns when GetConfigIDByTreeID gives nothing: tree ids,
		-- names and the cap survive, every currency field is gone.
		local function unreadTrees()
			local spend = fixture("dump_trees_fresh").treeSpend
			spend.unspent, spend.spent = nil, nil
			for _, treeId in ipairs(spend.treeIds) do
				local tree = spend[treeId]
				tree.configId, tree.quantity, tree.spent, tree.spentInTree = nil, nil, nil, nil
			end
			return spend
		end

		it("keeps the last good tree spend when no tree's currency was read", function()
			local stored = fixture("dump_trees_fresh").treeSpend
			stored[1187].spentInTree, stored[1188].spentInTree = 5, 3 -- derived: captured 0, varied
			stored.unspent = 2 -- derived: captured 0, varied
			local previous = Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character, treeSpend = stored, now = 1000,
			})

			local fresh = Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character, treeSpend = unreadTrees(), now = 2000,
			})
			local merged = Model.MergeSnapshot(previous, fresh)

			assert.is_nil(fresh.trees)
			assert.equals("unspent points not read", fresh.treesReason)
			assert.equals(5, merged.trees[1].spent)
			assert.equals(3, merged.trees[2].spent)
			assert.equals(2, merged.unspent)
			assert.equals(1000, merged.treesAt)
		end)

		it("counts a read with one tree missing its spend as failed", function()
			local spend = fixture("dump_trees_fresh").treeSpend
			spend[1188].spentInTree = nil

			local snapshot = Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character, treeSpend = spend, now = 1000,
			})

			assert.is_nil(snapshot.trees)
			assert.equals("tree spend not read for 1188", snapshot.treesReason)
		end)

		local function withProfessions(list, reason, now)
			local character = fixture("dump_character_shaman").character
			character.professions = list -- derived: captured {}, varied
			character.professionsReason = reason
			return Model.BuildSnapshot({ character = character, now = now })
		end

		local TWO = { { name = "Alchemy", skillLineId = 171, skill = 120 },
			{ name = "Herbalism", skillLineId = 182, skill = 90 } }

		it("keeps stored professions over a partial read", function()
			local previous = withProfessions(TWO, nil, 1000)
			local fresh = withProfessions({ TWO[2] }, "partial: slot 1: error: boom", 2000)

			local merged = Model.MergeSnapshot(previous, fresh)

			assert.is_nil(fresh.professions)
			assert.equals(2, #merged.professions)
			assert.equals(1000, merged.professionsAt)
			assert.equals("partial: slot 1: error: boom", merged.professionsReason)
		end)

		it("keeps stored professions over an empty read, and says so", function()
			local previous = withProfessions(TWO, nil, 1000)

			local merged = Model.MergeSnapshot(previous, withProfessions({}, nil, 2000))

			assert.equals(2, #merged.professions)
			assert.equals(1000, merged.professionsAt)
			assert.equals("empty read, kept stored", merged.professionsReason)
		end)

		it("takes a complete read over the stored one", function()
			local previous = withProfessions(TWO, nil, 1000)

			local merged = Model.MergeSnapshot(previous, withProfessions({ TWO[1] }, nil, 2000))

			assert.equals(1, #merged.professions)
			assert.equals(2000, merged.professionsAt)
			assert.is_nil(merged.professionsReason)
		end)

		it("takes the fresh snapshot whole when nothing was stored", function()
			local fresh = captured(1000)

			assert.equals(fresh, Model.MergeSnapshot(nil, fresh))
		end)
	end)

	describe("Roster", function()
		it("puts the current character first, then by level, then by key", function()
			local roster = Model.Roster({
				alt("B-R", 20), alt("A-R", 20), alt("C-R", 60), alt("Me-R", 1), "junk",
			}, "Me-R")

			local keys = {}
			for index, row in ipairs(roster.rows) do
				keys[index] = row.key
			end
			assert.same({ "Me-R", "C-R", "A-R", "B-R" }, keys)
			assert.equals(1, roster.skipped)
		end)
	end)

	describe("ProfessionCandidates", function()
		local challenges

		before_each(function()
			challenges = fixture("dump_challenges_page1_fresh").challenges
		end)

		it("finds the one skill line the captured tradeskill challenges name", function()
			assert.same({ 2937 }, Model.ChallengeSkillLines(challenges))
		end)

		it("lists every tradeskill challenge with no candidates when no alt knows the line", function()
			local shaman = Model.BuildSnapshot({ character = fixture("dump_character_shaman").character })

			local result = Model.ProfessionCandidates(challenges, { shaman }, nil)

			assert.equals(3, #result)
			assert.equals(150, byName(result, "Journeyman Alchemist").need)
			assert.equals(0, #byName(result, "Journeyman Alchemist").candidates)
		end)

		it("matches through the skill line's parent and ranks the closest alt first", function()
			local parents = { [2937] = { parentId = 171 } }
			local alts = {
				alt("Low-R", 30, { { skillLineId = 171, skill = 40 } }),
				alt("High-R", 40, { { skillLineId = 171, skill = 130 } }),
				alt("Other-R", 40, { { skillLineId = 999, skill = 300 } }),
			}

			local journeyman = byName(Model.ProfessionCandidates(challenges, alts, parents), "Journeyman Alchemist")

			assert.equals(2, #journeyman.candidates)
			assert.equals("High-R", journeyman.candidates[1].key)
			assert.equals(20, journeyman.candidates[1].remaining)
			assert.equals(110, journeyman.candidates[2].remaining)
		end)

		it("matches the challenge's skill line directly too", function()
			local alts = { alt("Direct-R", 30, { { skillLineId = 2937, skill = 160 } }) }

			local result = Model.ProfessionCandidates(challenges, alts, nil)

			local journeyman = byName(result, "Journeyman Alchemist").candidates[1]
			assert.equals(0, journeyman.remaining)
			assert.is_true(journeyman.reached)
			assert.equals(65, byName(result, "Expert Alchemist").candidates[1].remaining)
		end)

		it("leaves out completed challenges", function()
			for _, challenge in ipairs(challenges) do
				challenge.completed = true -- derived: captured false, varied
			end

			assert.same({}, Model.ProfessionCandidates(challenges, {}, nil))
		end)

		pending("S1 + D4: a captured profession joins a captured tradeskill challenge")
	end)
end)
