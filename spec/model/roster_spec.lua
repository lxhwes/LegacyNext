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

-- Geo Prizm's UnitGUID as the D10 probe read it on 70170 (docs/legacy-internals.md, "D10
-- closed"). dump_character_geo.lua is a 70124 capture from before Api read the GUID, so it is
-- added to that character here, by hand.
local GEO_GUID = "Player-4619-012F81BC"

local function geoWithGuid()
	local character = fixture("dump_character_geo").character
	character.guid = GEO_GUID -- taken from the D10 probe, not from this capture
	return character
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

		-- UnitName's first return lost the surname between 69913 and 70124, so Name-Realm can
		-- split one character in two. The GUID does not move.
		it("keys on the GUID when the character has one", function()
			assert.equals(GEO_GUID, Model.CharacterKey(geoWithGuid()))
		end)

		it("falls back to Name-Realm when the GUID was not read", function()
			local character = geoWithGuid()
			character.guid = ""

			assert.equals("Geo-Classic Beta PvP", Model.CharacterKey(character))
			character.guid = nil
			assert.equals("Geo-Classic Beta PvP", Model.CharacterKey(character))
		end)

		it("still builds the Name-Realm key for a character with a GUID", function()
			assert.equals("Geo-Classic Beta PvP", Model.LegacyCharacterKey(geoWithGuid()))
		end)
	end)

	describe("CharacterLabel", function()
		it("names the character, and adds the realm only when asked", function()
			local snapshot = Model.BuildSnapshot({ character = geoWithGuid(), now = 1 })

			assert.equals("Geo", Model.CharacterLabel(snapshot))
			assert.equals("Geo-Classic Beta PvP", Model.CharacterLabel(snapshot, true))
		end)

		it("never shows a GUID, even when the name was not read", function()
			local snapshot = { key = GEO_GUID, guid = GEO_GUID, realm = "Classic Beta PvP" }

			assert.equals("?", Model.CharacterLabel(snapshot))
			assert.equals("?-Classic Beta PvP", Model.CharacterLabel(snapshot, true))
		end)

		it("shows a nameless row's Name-Realm key, which is readable", function()
			assert.equals("A-R", Model.CharacterLabel({ key = "A-R" }, true))
		end)
	end)

	describe("PlanSnapshot", function()
		-- Geo's row as the addon stored it in game, under the Name-Realm key (S1, 70124).
		local function storedGeo()
			return fixture("roster_geo_restart").snapshots[1]
		end

		local function freshGeo(now)
			local character = geoWithGuid()
			character.professions = nil
			character.professionsReason = "GetProfessions unavailable"
			return Model.BuildSnapshot({ character = character, now = now })
		end

		it("moves the character's Name-Realm row to its GUID, keeping what this read missed", function()
			local legacy = storedGeo()

			local plan = Model.PlanSnapshot(freshGeo(2000000000), nil, legacy)

			assert.equals(GEO_GUID, plan.snapshot.key)
			assert.equals(GEO_GUID, plan.snapshot.guid)
			assert.equals("Geo", plan.snapshot.name)
			assert.equals("Classic Beta PvP", plan.snapshot.realm)
			assert.same(legacy.professions, plan.snapshot.professions)
			assert.equals(legacy.professionsAt, plan.snapshot.professionsAt)
			assert.same(legacy.trees, plan.snapshot.trees)
			assert.equals("Geo-Classic Beta PvP", plan.forget)
		end)

		-- MergeSnapshot alone refuses a previous row under another key; the move is explicit.
		it("does the rekey itself, since MergeSnapshot keeps refusing another key", function()
			local fresh = freshGeo(2000000000)

			assert.equals(fresh, Model.MergeSnapshot(storedGeo(), fresh))
		end)

		it("merges over the GUID row and leaves any Name-Realm row alone once one exists", function()
			local legacy = storedGeo()
			local stored = Model.BuildSnapshot({ character = geoWithGuid(), now = 1000 })

			local plan = Model.PlanSnapshot(freshGeo(2000), stored, legacy)

			assert.is_nil(plan.forget)
			assert.same(stored.professions, plan.snapshot.professions)
			assert.equals(1000, plan.snapshot.professionsAt)
		end)

		it("does not take a Name-Realm row that already belongs to another GUID", function()
			local legacy = storedGeo()
			legacy.guid = "Player-1-00000002" -- derived: not a captured GUID

			local plan = Model.PlanSnapshot(freshGeo(2000), nil, legacy)

			assert.is_nil(plan.forget)
			assert.is_nil(plan.snapshot.professions)
		end)

		-- The Shaman read "Bong Wrip" on 69913 and was stored as "Bong" on 70124. Only an exact
		-- Name-Realm match moves, so this pair stays two rows until /lgn roster forget.
		it("does not take a row stored under a different name", function()
			local shaman = fixture("dump_character_shaman").character
			shaman.guid = GEO_GUID -- derived: the Shaman's GUID was never read
			local fresh = Model.BuildSnapshot({ character = shaman, now = 2000 })

			local plan = Model.PlanSnapshot(fresh, nil, fixture("roster_geo_restart").snapshots[2])

			assert.is_nil(plan.forget)
			assert.equals(fresh, plan.snapshot)
		end)

		it("merges a Name-Realm keyed snapshot over its own row, as before GUIDs", function()
			local character = fixture("dump_character_geo").character
			character.professions = nil
			local fresh = Model.BuildSnapshot({ character = character, now = 2000000000 })
			local legacy = storedGeo()

			local plan = Model.PlanSnapshot(fresh, legacy, legacy)

			assert.equals("Geo-Classic Beta PvP", plan.snapshot.key)
			assert.is_nil(plan.snapshot.guid)
			assert.is_nil(plan.forget)
			assert.same(legacy.professions, plan.snapshot.professions)
		end)

		it("takes the fresh snapshot whole when nothing was stored", function()
			local fresh = freshGeo(2000)

			local plan = Model.PlanSnapshot(fresh, nil, nil)

			assert.equals(fresh, plan.snapshot)
			assert.is_nil(plan.forget)
		end)
	end)

	describe("ForgetKey", function()
		local function snapshots()
			local geo = Model.BuildSnapshot({ character = geoWithGuid(), now = 1 })
			return { geo, fixture("roster_geo_restart").snapshots[2] }
		end

		it("takes a stored key as it is", function()
			assert.equals(GEO_GUID, Model.ForgetKey(GEO_GUID, snapshots()))
			assert.equals("Bong-Classic Beta PvP", Model.ForgetKey("Bong-Classic Beta PvP", snapshots()))
		end)

		it("finds a GUID-keyed character by Name-Realm", function()
			assert.equals(GEO_GUID, Model.ForgetKey("Geo-Classic Beta PvP", snapshots()))
		end)

		it("refuses a Name-Realm two characters share, and names their keys", function()
			local list = snapshots()
			local other = Model.BuildSnapshot({ character = geoWithGuid(), now = 1 })
			other.key, other.guid = "Player-1-00000002", "Player-1-00000002" -- derived: not a captured GUID
			list[#list + 1] = other

			local key, reason = Model.ForgetKey("Geo-Classic Beta PvP", list)

			assert.is_nil(key)
			assert.equals("2 characters are Geo-Classic Beta PvP: Player-1-00000002, " .. GEO_GUID, reason)
		end)

		it("says when nothing matches", function()
			local key, reason = Model.ForgetKey("Nobody-Classic Beta PvP", snapshots())

			assert.is_nil(key)
			assert.equals("no character Nobody-Classic Beta PvP", reason)
			assert.is_nil(Model.ForgetKey("", snapshots()))
		end)
	end)

	describe("BuildSnapshot", function()
		-- D4, 2026-10-01: Api's read of a character with three professions, and the snapshot
		-- the addon stored from that character in game the same session. They agree.
		it("keeps every captured profession, as the addon stored it in game", function()
			local snapshot = Model.BuildSnapshot({ character = fixture("dump_character_geo").character, now = 1 })

			assert.same({
				{ name = "Alchemy", skillLineId = 171, skill = 1, max = 75 },
				{ name = "Herbalism", skillLineId = 182, skill = 20, max = 75 },
				{ name = "Cooking", skillLineId = 185, skill = 1, max = 75 },
			}, snapshot.professions)
			assert.same(fixture("roster_geo_restart").snapshots[1].professions, snapshot.professions)
		end)

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

		it("keys the snapshot on the GUID and keeps the name and realm beside it", function()
			local snapshot = Model.BuildSnapshot({ character = geoWithGuid(), now = 1 })

			assert.equals(GEO_GUID, snapshot.key)
			assert.equals(GEO_GUID, snapshot.guid)
			assert.equals("Geo", snapshot.name)
			assert.equals("Classic Beta PvP", snapshot.realm)
		end)

		it("stores no guid on a snapshot keyed by Name-Realm", function()
			local snapshot = Model.BuildSnapshot({ character = fixture("dump_character_geo").character, now = 1 })

			assert.equals("Geo-Classic Beta PvP", snapshot.key)
			assert.is_nil(snapshot.guid)
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
			-- One rule for "kept from before", read by the Roster tab and /lgn roster alike.
			assert.equals(1000, Model.KeptAt(merged, "professions"))
			assert.equals(1000, Model.KeptAt(merged, "trees"))
			assert.is_nil(Model.KeptAt(previous, "professions"))
			assert.is_nil(Model.KeptAt(fresh, "trees"))
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

		-- 171 and 200 stand in for whatever the lookup reports; see alt().
		describe("MergeSkillLineParents", function()
			it("keeps a saved answer over a live one that names no id", function()
				local merged = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } },
					{ [2937] = { name = "", raw = { professionID = 0 } } })

				assert.equals(171, merged[2937].parentId)
				assert.is_true(merged[2937].saved)
			end)

			it("lets a live answer with an id replace the saved one", function()
				local merged = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } },
					{ [2937] = { parentId = 200 }, [2938] = { professionId = 2938 } })

				assert.equals(200, merged[2937].parentId)
				assert.is_nil(merged[2937].saved)
				assert.equals(2938, merged[2938].professionId)
			end)

			-- The window merges on every read, on every character. An alt whose lookup names only the
			-- line, or an id with no parent, must not erase the parent the Alchemist saved.
			it("keeps a saved parent over a live answer without one", function()
				local saved = { [2937] = { parentId = 171 } }

				local echo = Model.MergeSkillLineParents(saved, { [2937] = { professionId = 2937 } })
				local other = Model.MergeSkillLineParents(saved, { [2937] = { professionId = 300 } })

				assert.equals(171, echo[2937].parentId)
				assert.is_true(echo[2937].saved)
				assert.equals(171, other[2937].parentId)
				assert.is_true(other[2937].saved)
			end)

			it("lets a live id replace a saved answer that names only the line", function()
				local merged = Model.MergeSkillLineParents({ [2937] = { professionId = 2937 } },
					{ [2937] = { professionId = 300 } })

				assert.equals(300, merged[2937].professionId)
				assert.is_nil(merged[2937].saved)
			end)

			it("reads a missing map on either side as empty", function()
				assert.same({}, Model.MergeSkillLineParents(nil, nil))
				assert.same({ [1] = { parentId = 2, saved = true } },
					Model.MergeSkillLineParents({ [1] = { parentId = 2 }, [3] = "junk" }, nil))
			end)

			it("joins an alt through a saved answer when this session's lookup failed", function()
				local parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
				local alts = { alt("Alch-R", 30, { { skillLineId = 171, skill = 100 } }) }

				local journeyman = byName(Model.ProfessionCandidates(challenges, alts, parents),
					"Journeyman Alchemist")

				assert.equals("Alch-R", journeyman.candidates[1].key)
			end)
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

		it("falls back to the line's professionId when it has no parent, as Blizzard's frame does", function()
			local parents = { [2937] = { professionId = 171 } } -- derived: 171 stands in, see alt()
			local alts = { alt("Alch-R", 30, { { skillLineId = 171, skill = 100 } }) }

			local journeyman = byName(Model.ProfessionCandidates(challenges, alts, parents), "Journeyman Alchemist")

			assert.equals(1, #journeyman.candidates)
			assert.equals(50, journeyman.candidates[1].remaining)
		end)

		-- The S1 unknown: the lookup may name the line itself and no parent. That id adds no way
		-- to join, so an empty list still proves nothing.
		it("counts a lookup that names only the challenge's own line as no answer", function()
			local echo = { [2937] = { professionId = 2937 } } -- derived: shape of Api.GetSkillLineParents
			local parent = { [2937] = { parentId = 171 } }

			local journeyman = byName(Model.ProfessionCandidates(challenges, {}, echo), "Journeyman Alchemist")

			assert.is_false(journeyman.parentKnown)
			assert.is_true(byName(Model.ProfessionCandidates(challenges, {}, parent), "Journeyman Alchemist").parentKnown)
		end)

		it("matches the challenge's skill line directly too", function()
			local alts = { alt("Direct-R", 30, { { skillLineId = 2937, skill = 160 } }) }

			local result = Model.ProfessionCandidates(challenges, alts, nil)

			local journeyman = byName(result, "Journeyman Alchemist").candidates[1]
			assert.equals(0, journeyman.remaining)
			assert.is_true(journeyman.reached)
			assert.equals(65, byName(result, "Expert Alchemist").candidates[1].remaining)
		end)

		it("skips stored snapshots it cannot read instead of failing the whole list", function()
			local keyless = alt("X", 30, { { skillLineId = 2937, skill = 100 } })
			keyless.key = nil
			local junkList = alt("Junk-R", 30, "oops")
			local junkEntry = alt("Entry-R", 30, { 7, { skillLineId = 2937, skill = 120 } })
			local good = alt("Good-R", 30, { { skillLineId = 2937, skill = 140 } })

			local result = Model.ProfessionCandidates(challenges, { keyless, junkList, junkEntry, good }, nil)

			local journeyman = byName(result, "Journeyman Alchemist").candidates
			assert.equals(2, #journeyman)
			assert.equals("Good-R", journeyman[1].key)
			assert.equals("Entry-R", journeyman[2].key)
		end)

		it("leaves out completed challenges", function()
			for _, challenge in ipairs(challenges) do
				challenge.completed = true -- derived: captured false, varied
			end

			assert.same({}, Model.ProfessionCandidates(challenges, {}, nil))
		end)

		-- S1, 2026-10-01 (spec/fixtures/roster_geo.lua): a real gatherer and the real lookup.
		it("joins a captured gatherer to no tradeskill challenge, with the lookup answered", function()
			local captured = fixture("roster_geo")

			local result = Model.ProfessionCandidates(challenges, captured.snapshots, captured.parentsLive)

			assert.equals(3, #result)
			for _, entry in ipairs(result) do
				assert.same({}, entry.candidates)
				assert.is_true(entry.parentKnown)
			end
		end)

		-- S1, 2026-10-01 (spec/fixtures/roster_geo_restart.lua): Alchemy reads the Classic line
		-- 171, and joins the Forever line 2937 only through the captured parent.
		it("joins a captured Alchemist to the Alchemy challenges through the parent line", function()
			local captured = fixture("roster_geo_restart")
			assert.equals(171, captured.snapshots[1].professions[1].skillLineId)

			local result = Model.ProfessionCandidates(challenges, captured.snapshots, captured.parents)

			local journeyman = byName(result, "Journeyman Alchemist")
			assert.is_true(journeyman.parentKnown)
			assert.equals(1, #journeyman.candidates)
			assert.equals("Geo-Classic Beta PvP", journeyman.candidates[1].key)
			assert.equals(1, journeyman.candidates[1].skill)
			assert.equals(149, journeyman.candidates[1].remaining)
			assert.equals(299, byName(result, "Artisan Alchemist").candidates[1].remaining)
		end)

		it("finds no captured Alchemist without the parent, so the direct match alone is not enough", function()
			local captured = fixture("roster_geo_restart")

			local result = Model.ProfessionCandidates(challenges, captured.snapshots, nil)

			assert.same({}, byName(result, "Journeyman Alchemist").candidates)
		end)
	end)

	describe("BuildRosterView", function()
		local shaman, challenges, parents
		local rewardTrack = fixture("dump_rewards_fresh").rewardTrack
		local NOW = 1000 + 600

		-- Model's own snapshot shape with derived values, like alt() above.
		local function zug(skill)
			local snapshot = alt("Zug-Classic Beta PvP", 30,
				{ { name = "Alchemy", skillLineId = 171, skill = skill or 120, max = 150 } })
			snapshot.name, snapshot.realm, snapshot.takenAt = "Zug", "Classic Beta PvP", 1000 - 7200
			snapshot.professionsAt = snapshot.takenAt
			return snapshot
		end

		local function rows(view, kind)
			local out = {}
			for _, row in ipairs(view.rows) do
				if row.kind == kind then
					out[#out + 1] = row
				end
			end
			return out
		end

		local function build(snapshots, extra)
			local input = { snapshots = snapshots, currentKey = shaman.key, now = NOW, rewardTrack = rewardTrack }
			for field, value in pairs(extra or {}) do
				input[field] = value
			end
			return Model.BuildRosterView(input)
		end

		before_each(function()
			shaman = Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character,
				treeSpend = fixture("dump_trees_fresh").treeSpend,
				now = 1000,
			})
			challenges = fixture("dump_challenges_page1_fresh").challenges
			-- 2937 -> 171 is the DB2 reading. What the live lookup returns is S1.
			parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
		end)

		it("draws the same reward-track header as Next Up, and no filter bar", function()
			local view = build({ shaman })

			assert.same(Model.Header(rewardTrack).lines, view.header.lines)
			assert.same({}, view.filters)
			assert.equals("roster", view.tab)
		end)

		it("puts the next reward's icon on the header, as Next Up does", function()
			assert.equals(135614, build({ shaman }).header.icon)
		end)

		it("lists the current character first, with tree spend and unspent points", function()
			local view = build({ zug(), shaman })
			local characters = rows(view, "character")

			assert.equals("ok", view.state)
			assert.equals("columns", view.rows[1].kind)
			assert.equals("P/A/R", view.rows[1].progressText) -- initials of the captured tree names
			assert.equals(2, #characters)
			assert.equals(shaman.key, characters[1].key)
			assert.is_true(characters[1].current)
			assert.equals("Bong Wrip  L1 Shaman", characters[1].name)
			assert.equals("0/0/0", characters[1].progressText)
			assert.equals("0", characters[1].pointsText)
			assert.equals("Zug  L30 Druid", characters[2].name)
			assert.is_false(characters[2].current)
		end)

		-- A session whose read missed a tree stores fewer trees. Its figures must still sit under
		-- the heading's own letters, not shift left into the wrong columns.
		it("lines each row's tree figures up under the heading's trees", function()
			local partial = zug()
			partial.trees = { { treeId = 1189, name = "Resourcefulness", spent = 4 }, -- derived: order and count varied
				{ treeId = 1187, name = "Professions", spent = 3 } }
			partial.unspent = 9
			local view = build({ partial, shaman })
			local characters = rows(view, "character")

			assert.equals("P/A/R", view.rows[1].progressText)
			assert.equals("0/0/0", characters[1].progressText)
			assert.equals("3/?/4", characters[2].progressText)
		end)

		it("shows ? for a part never read, never zero", function()
			local characters = rows(build({ zug(), shaman }), "character")

			assert.equals("?", characters[2].progressText)
			assert.equals("?", characters[2].pointsText)
		end)

		it("spells out trees, unspent points, professions and age in the tooltip", function()
			local characters = rows(build({ zug(), shaman }), "character")
			local shamanDetail = table.concat(characters[1].detail, "\n")
			local zugDetail = table.concat(characters[2].detail, "\n")

			assert.equals("Classic Beta PvP", characters[1].category)
			assert.truthy(shamanDetail:find("Spent: Professions 0, Adventure 0, Resourcefulness 0", 1, true))
			assert.truthy(shamanDetail:find("Unspent: 0 of 16", 1, true))
			assert.truthy(shamanDetail:find("No professions", 1, true))
			assert.truthy(shamanDetail:find("Updated 10m ago", 1, true))
			assert.truthy(zugDetail:find("Alchemy 120/150", 1, true))
			assert.truthy(zugDetail:find("Tree spend not read", 1, true))
			assert.truthy(zugDetail:find("Updated 2h ago", 1, true))
		end)

		it("dates a part kept from an earlier snapshot", function()
			local kept = Model.MergeSnapshot(zug(), { key = "Zug-Classic Beta PvP", name = "Zug",
				realm = "Classic Beta PvP", takenAt = NOW, professionsReason = "not read" })
			local detail = table.concat(rows(build({ kept, shaman }), "character")[2].detail, "\n")

			assert.truthy(detail:find("Alchemy 120/150", 1, true))
			assert.truthy(detail:find("Professions from 2h ago: not read", 1, true))
		end)

		it("adds the realm to names only when the roster spans realms", function()
			local other = zug()
			other.realm, other.key = "Elsewhere", "Zug-Elsewhere"
			local characters = rows(build({ other, shaman }), "character")

			assert.equals("Bong Wrip-Classic Beta PvP  L1 Shaman", characters[1].name)
			assert.equals("Zug-Elsewhere  L30 Druid", characters[2].name)
		end)

		-- A GUID is a key, not a name: the realm comes from the snapshot's own fields.
		it("builds Name-Realm from the snapshot, never from a GUID key", function()
			local geo = Model.BuildSnapshot({ character = geoWithGuid(), now = 1000 })
			local other = zug()
			other.realm, other.key, other.guid = "Elsewhere", "Player-1-00000002", "Player-1-00000002" -- derived
			local snapshots = { geo, other }
			local view = Model.BuildRosterView({ snapshots = snapshots, currentKey = geo.key, now = NOW,
				candidates = Model.ProfessionCandidates(challenges, snapshots, parents) })
			local characters = rows(view, "character")

			assert.equals("Geo-Classic Beta PvP  L6 Druid", characters[1].name)
			assert.equals(GEO_GUID, characters[1].key)
			assert.is_true(characters[1].current)
			assert.equals("Zug-Elsewhere  L30 Druid", characters[2].name)
			local tradeskill = rows(view, "tradeskill")[1]
			assert.equals("Journeyman Alchemist" .. Model.SEPARATOR .. "Zug-Elsewhere", tradeskill.name)
			for _, row in ipairs(view.rows) do
				assert.is_nil(tostring(row.name):find("Player-", 1, true), row.name)
				for _, line in ipairs(row.detail or {}) do
					assert.is_nil(line:find("Player-", 1, true), line)
				end
			end
		end)

		it("lists tradeskill challenges with the closest character and every candidate", function()
			local close, far = zug(140), zug(60)
			far.name, far.key = "Far", "Far-Classic Beta PvP"
			local snapshots = { close, far, shaman }
			local view = build(snapshots, { candidates = Model.ProfessionCandidates(challenges, snapshots, parents) })
			local tradeskills = rows(view, "tradeskill")

			assert.equals("columns", view.rows[#rows(view, "character") + 2].kind)
			assert.equals(3, #tradeskills) -- Journeyman, Expert and Artisan Alchemist, all on page 1
			assert.equals("Journeyman Alchemist" .. Model.SEPARATOR .. "Zug", tradeskills[1].name)
			assert.equals("140/150", tradeskills[1].progressText)
			assert.equals("1pt", tradeskills[1].pointsText)
			local detail = table.concat(tradeskills[1].detail, "\n")
			assert.truthy(detail:find("Reach 150 skill in Alchemy for the first time.", 1, true))
			assert.truthy(detail:find("Zug  140/150, 10 to go", 1, true))
			assert.truthy(detail:find("Far  60/150, 90 to go", 1, true))
		end)

		it("names the realm on tradeskill rows when the roster spans realms", function()
			local here, there = zug(140), zug(60)
			there.realm, there.key = "Elsewhere", "Zug-Elsewhere"
			local snapshots = { here, there, shaman }
			local tradeskills = rows(build(snapshots,
				{ candidates = Model.ProfessionCandidates(challenges, snapshots, parents) }), "tradeskill")

			assert.equals("Journeyman Alchemist" .. Model.SEPARATOR .. "Zug-Classic Beta PvP", tradeskills[1].name)
			local detail = table.concat(tradeskills[1].detail, "\n")
			assert.truthy(detail:find("Zug-Classic Beta PvP  140/150, 10 to go", 1, true))
			assert.truthy(detail:find("Zug-Elsewhere  60/150, 90 to go", 1, true))
		end)

		it("orders tradeskill rows by the closest character, not client order", function()
			local reversed = {}
			for index = #challenges, 1, -1 do
				reversed[#reversed + 1] = challenges[index]
			end
			local snapshots = { zug(140), shaman }
			local tradeskills = rows(build(snapshots,
				{ candidates = Model.ProfessionCandidates(reversed, snapshots, parents) }), "tradeskill")

			assert.equals("140/150", tradeskills[1].progressText)
			assert.equals("140/225", tradeskills[2].progressText)
			assert.equals("140/300", tradeskills[3].progressText)
		end)

		it("says a character already past the threshold has reached it", function()
			local snapshots = { zug(160), shaman }
			local tradeskills = rows(build(snapshots,
				{ candidates = Model.ProfessionCandidates(challenges, snapshots, parents) }), "tradeskill")

			assert.equals("160/150", tradeskills[1].progressText)
			assert.truthy(table.concat(tradeskills[1].detail, "\n"):find("Zug  160/150, already reached", 1, true))
		end)

		it("hides tradeskill challenges nobody saved can work on, with a count", function()
			local view = build({ shaman }, { candidates = Model.ProfessionCandidates(challenges, { shaman }, parents) })

			assert.equals(0, #rows(view, "tradeskill"))
			assert.equals(1, #rows(view, "columns"))
			assert.truthy(view.footnote:find("3 tradeskill challenges have no saved character with the profession",
				1, true))
		end)

		it("says when the profession lookup gave no answer for the hidden ones", function()
			local snapshots = { zug(), shaman }
			local view = build(snapshots, { candidates = Model.ProfessionCandidates(challenges, snapshots, nil) })

			assert.equals(0, #rows(view, "tradeskill"))
			assert.truthy(view.footnote:find("3 tradeskill challenges have no saved character with the profession."
				.. " The profession lookup gave no answer for 3 of them, so a match may be missing", 1, true))
		end)

		-- A read-only store or a failed realm read leaves the tab empty or stale on a character
		-- that has logged in. The empty state alone would say it never logged in.
		it("says first when this character's snapshot was not saved, and why", function()
			local view = build({}, { snapshotProblem = "saved schema 2, this build reads 1" })

			assert.equals("empty", view.state)
			assert.equals("This character was not saved: saved schema 2, this build reads 1", view.footnote)
			local stale = build({ shaman, "junk" }, { snapshotProblem = "no realm" })
			assert.equals("This character was not saved: no realm\n1 saved character could not be read", stale.footnote)
		end)

		it("adds no tradeskill count under an empty roster", function()
			local view = build({}, { candidates = Model.ProfessionCandidates(challenges, {}, parents) })

			assert.equals("empty", view.state)
			assert.is_nil(view.footnote)
		end)

		it("says when the tradeskill challenges could not be read", function()
			local view = build({ shaman }, { challengesReason = "GetCategoryList unavailable" })

			assert.truthy(view.footnote:find("Could not read tradeskill challenges: GetCategoryList unavailable", 1, true))
			assert.equals(1, #rows(view, "character"))
		end)

		it("counts stored rows it could not read", function()
			local view = build({ shaman, "junk", { level = 3 } })

			assert.equals(1, #rows(view, "character"))
			assert.truthy(view.footnote:find("2 saved characters could not be read", 1, true))
		end)

		-- S1, 2026-10-01. `now` is not in the capture; 10 s after Geo's snapshot reproduces every
		-- age the paste printed (0m, 47m, 48m).
		it("draws the captured roster, with Bong's trees kept from login", function()
			local captured = fixture("roster_geo")
			local view = Model.BuildRosterView({
				snapshots = captured.snapshots,
				currentKey = "Geo-Classic Beta PvP",
				now = captured.snapshots[1].takenAt + 10,
				candidates = Model.ProfessionCandidates(challenges, captured.snapshots, captured.parentsLive),
			})
			local characters = rows(view, "character")

			assert.equals("ok", view.state)
			assert.equals(2, #characters)
			assert.equals("Geo-Classic Beta PvP", characters[1].key)
			assert.is_true(characters[1].current)
			assert.equals("Bong-Classic Beta PvP", characters[2].key)
			local geo = table.concat(characters[1].detail, "\n")
			local bong = table.concat(characters[2].detail, "\n")
			assert.truthy(geo:find("Herbalism 13/75", 1, true))
			assert.truthy(geo:find("Cooking 1/75", 1, true))
			assert.truthy(bong:find("Trees from 48m ago: unspent points not read", 1, true))
			assert.truthy(bong:find("Updated 47m ago", 1, true))
			assert.equals(0, #rows(view, "tradeskill"))
			assert.truthy(view.footnote:find("3 tradeskill challenges have no saved character with the profession",
				1, true))
			assert.is_nil(view.footnote:find("lookup gave no answer", 1, true))
		end)

		-- S1, 2026-10-01 (spec/fixtures/roster_geo_restart.lua): the class token the frame
		-- colours a name by, and each tradeskill challenge's own icon.
		it("carries the captured class tokens and each tradeskill challenge's icon", function()
			local captured = fixture("roster_geo_restart")
			local view = Model.BuildRosterView({
				snapshots = captured.snapshots,
				currentKey = "Geo-Classic Beta PvP",
				now = captured.snapshots[1].takenAt,
				candidates = Model.ProfessionCandidates(challenges, captured.snapshots, captured.parents),
			})
			local characters, tradeskills = rows(view, "character"), rows(view, "tradeskill")

			assert.equals("DRUID", characters[1].classToken)
			assert.equals("SHAMAN", characters[2].classToken)
			assert.equals(3, #tradeskills)
			for _, row in ipairs(tradeskills) do
				assert.equals(136240, row.icon) -- Alchemy's, on all three tiers
				assert.is_nil(row.classToken)
			end
			for _, row in ipairs(characters) do
				assert.is_nil(row.icon)
			end
		end)

		it("leaves the class token nil unless it is a non-empty string", function()
			local captured = fixture("roster_geo")
			captured.snapshots[1].classToken = "" -- derived: captured "DRUID", emptied
			captured.snapshots[2].classToken = 7 -- derived: captured "SHAMAN", varied to a non-string
			local byKey = {}
			for _, row in ipairs(rows(build({ captured.snapshots[1], captured.snapshots[2], zug() }), "character")) do
				byKey[row.key] = row
			end

			assert.is_nil(byKey["Geo-Classic Beta PvP"].classToken)
			assert.is_nil(byKey["Bong-Classic Beta PvP"].classToken)
			assert.is_nil(byKey["Zug-Classic Beta PvP"].classToken) -- Model's own shape, which has none
		end)

		it("leaves a tradeskill row's icon nil when the challenge's is missing or empty", function()
			byName(challenges, "Journeyman Alchemist").icon = nil -- derived: captured 136240, removed
			byName(challenges, "Expert Alchemist").icon = "" -- derived: captured 136240, emptied
			local snapshots = { zug(140), shaman }
			local tradeskills = rows(build(snapshots,
				{ candidates = Model.ProfessionCandidates(challenges, snapshots, parents) }), "tradeskill")

			assert.equals(62012, tradeskills[1].id) -- Journeyman, 10 to go
			assert.is_nil(tradeskills[1].icon)
			assert.equals(62013, tradeskills[2].id) -- Expert
			assert.is_nil(tradeskills[2].icon)
			assert.equals(136240, tradeskills[3].icon) -- Artisan, untouched
		end)

		it("has an empty state and an error state", function()
			local empty = Model.BuildRosterView({ snapshots = {} })
			local failed = Model.BuildRosterView({ error = "attempt to index nil" })

			assert.equals("empty", empty.state)
			assert.truthy(empty.message:find("No characters saved yet", 1, true))
			assert.equals("error", failed.state)
			assert.equals("Could not read the roster: attempt to index nil", failed.message)
		end)
	end)

	describe("Next Up tooltip candidates", function()
		local challenges

		before_each(function()
			challenges = fixture("dump_challenges_page1_fresh").challenges
		end)

		local function journeymanDetail(input)
			input.challenges = challenges
			return table.concat(byName(Model.BuildView(input).rows, "Journeyman Alchemist").detail, "\n")
		end

		it("names the characters with the profession on a tradeskill row", function()
			local parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
			local zug = alt("Zug-R", 30, { { name = "Alchemy", skillLineId = 171, skill = 120, max = 150 } })
			zug.name = "Zug"

			local detail = journeymanDetail({ candidates = Model.ProfessionCandidates(challenges, { zug }, parents) })

			assert.truthy(detail:find("Zug  120/150, 30 to go", 1, true))
		end)

		it("names the realm in the tooltip when saved characters span realms", function()
			local parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
			local here = alt("Zug-R", 30, { { name = "Alchemy", skillLineId = 171, skill = 120, max = 150 } })
			local there = alt("Zug-S", 30, { { name = "Alchemy", skillLineId = 171, skill = 90, max = 150 } })
			here.name, here.realm, there.name, there.realm = "Zug", "R", "Zug", "S"

			local detail = journeymanDetail({
				candidates = Model.ProfessionCandidates(challenges, { here, there }, parents),
			})

			assert.truthy(detail:find("Zug-R  120/150, 30 to go", 1, true))
			assert.truthy(detail:find("Zug-S  90/150, 60 to go", 1, true))
		end)

		it("says so when no saved character has the profession", function()
			local parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
			local detail = journeymanDetail({ candidates = Model.ProfessionCandidates(challenges, {}, parents) })

			assert.truthy(detail:find("No saved character has this profession", 1, true))
		end)

		-- Without the skill-line lookup, a character whose profession reads as the parent line
		-- cannot match. "Nobody has it" would then be a claim the join cannot make (S1).
		it("says the lookup gave no answer instead of claiming nobody has the profession", function()
			local zug = alt("Zug-R", 30, { { name = "Alchemy", skillLineId = 171, skill = 120, max = 150 } })

			local detail = journeymanDetail({ candidates = Model.ProfessionCandidates(challenges, { zug }, nil) })

			assert.is_nil(detail:find("No saved character has this profession", 1, true))
			assert.truthy(detail:find("No saved character matched, and the profession lookup gave no answer", 1, true))
		end)

		it("adds nothing when no candidates were passed", function()
			local detail = journeymanDetail({})

			assert.is_nil(detail:find("saved character", 1, true))
			assert.is_nil(detail:find("to go", 1, true))
		end)
	end)

	-- S2, 2026-10-02 (spec/fixtures/roster_bong_migrated.lua): the store after Geo and Bong moved
	-- to their GUIDs in game, with Plymouth still under its Name-Realm key.
	describe("the migrated store, as captured", function()
		local BONG_GUID = "Player-4619-00BADC1B"

		local function captured()
			return fixture("roster_bong_migrated").snapshots
		end

		local function keyed(list, key)
			for _, snapshot in ipairs(list) do
				if snapshot.key == key then
					return snapshot
				end
			end
			error("no snapshot keyed " .. key)
		end

		it("merges the next login over the GUID row and moves nothing again", function()
			local stored = keyed(captured(), BONG_GUID)
			local fresh = keyed(captured(), BONG_GUID)
			fresh.takenAt = 1790990590 -- the /reload's own read, from the second paste

			local plan = Model.PlanSnapshot(fresh, stored, nil)

			assert.is_nil(plan.forget)
			assert.equals(BONG_GUID, plan.snapshot.key)
			assert.equals("Bong", plan.snapshot.name)
		end)

		it("draws every character by name, never by GUID, with the current one marked", function()
			local view = Model.BuildRosterView({ snapshots = captured(), currentKey = BONG_GUID })

			local names, current = {}, nil
			for _, row in ipairs(view.rows) do
				if row.kind == "character" then
					names[#names + 1] = row.name
					assert.is_nil(row.name:find("Player-", 1, true))
					if row.current then
						current = row.name
					end
				end
			end
			table.sort(names)
			assert.same({ "Bong  L1 Shaman", "Geo  L7 Druid", "Plymouth  L1 Paladin" }, names)
			assert.equals("Bong  L1 Shaman", current)
		end)

		it("forgets a moved character and an unmoved one by the Name-Realm a player types", function()
			assert.equals(BONG_GUID, Model.ForgetKey("Bong-Classic Beta PvP", captured()))
			assert.equals(GEO_GUID, Model.ForgetKey("Geo-Classic Beta PvP", captured()))
			assert.equals("Plymouth-Classic Beta PvP", Model.ForgetKey("Plymouth-Classic Beta PvP", captured()))
		end)
	end)
end)
