local helper = require("spec.spec_helper")

-- Debug.RenderRoster is /lgn roster's text. Rendered here against the captured character,
-- trees and page-1 challenges; no populated profession has been captured yet (D4).
local function loadStack()
	local ns = helper.loadAddonFile("LegacyNext/Model/Model.lua")
	helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
	helper.loadAddonFile("LegacyNext/Debug/Debug.lua", ns)
	return ns
end

local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

describe("Debug.RenderRoster", function()
	it("renders the captured character, its trees and the tradeskill challenges", function()
		local ns = loadStack()
		local Model = ns.Model
		local snapshot = Model.BuildSnapshot({
			character = fixture("dump_character_shaman").character,
			treeSpend = fixture("dump_trees_fresh").treeSpend,
			now = 1000,
		})
		local challenges = fixture("dump_challenges_page1_fresh").challenges

		local text = ns.Debug.RenderRoster({
			roster = Model.Roster({ snapshot }, snapshot.key),
			candidates = Model.ProfessionCandidates(challenges, { snapshot }, nil),
			diagnostics = { attached = true, loadedType = "table", loadedSessions = 2,
				loadedCharacters = 1, sessions = 3, characters = 1,
				loadedLog = { { session = 2, at = 1000 - 120, text = "PLAYER_LOGOUT -> written" } } },
			snapshotLog = { { at = 1000, text = "PLAYER_LOGIN -> written" } },
			parentsReason = "2937: missing",
			now = 1000 + 600,
		})

		assert.truthy(text:find("sessions=3 characters=1", 1, true))
		assert.truthy(text:find("snapshots this session:\n  10m ago  PLAYER_LOGIN -> written", 1, true))
		assert.truthy(text:find("snapshots saved by earlier sessions:\n  session 2  12m ago  PLAYER_LOGOUT -> written",
			1, true))
		assert.truthy(text:find("* Bong Wrip-Classic Beta PvP  L1 Shaman  10m ago", 1, true))
		assert.truthy(text:find("Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16", 1, true))
		assert.truthy(text:find("no professions", 1, true))
		assert.truthy(text:find("parent lookup: 2937: missing", 1, true))
		assert.truthy(text:find("Journeyman Alchemist  [line 2937, parent nil, profession nil]  need 150", 1, true))
		-- No lookup answer, so only a direct match could join: the paste must not claim nobody has it.
		assert.is_nil(text:find("no stored character has this profession", 1, true))
		assert.truthy(text:find("no stored character matched, and the profession lookup gave no answer, so one"
			.. " may be missing", 1, true))
	end)

	it("says when a part of a snapshot was never read", function()
		local ns = loadStack()
		local roster = ns.Model.Roster({ { key = "A-R", level = 5, class = "Druid" } }, nil)

		local text = ns.Debug.RenderRoster({ roster = roster, diagnostics = { readOnly = true,
			reason = "saved schema 2", lateLoads = 1, globalIsOurs = false },
			eventsNotRegistered = { "TRAIT_CONFIG_UPDATED (unknown to this client)" } })

		assert.truthy(text:find("READ ONLY: saved schema 2", 1, true))
		assert.truthy(text:find("LATE LOAD: the client replaced LegacyNextDB after ADDON_LOADED 1 time(s)", 1, true))
		assert.truthy(text:find("NOT SAVED: LegacyNextDB is no longer the table being written", 1, true))
		assert.truthy(text:find("events not registered: TRAIT_CONFIG_UPDATED (unknown to this client)", 1, true))
		assert.truthy(text:find("trees ?", 1, true))
		assert.truthy(text:find("professions ?", 1, true))
	end)

	it("renders a junk stored row instead of failing the paste", function()
		local ns = loadStack()
		local roster = ns.Model.Roster({ { key = "A-R", professions = "oops", trees = 7 },
			{ key = "B-R", professions = { 7 }, trees = { "x" } } }, nil)

		local text = ns.Debug.RenderRoster({ roster = roster })

		assert.truthy(text:find("A-R", 1, true))
		assert.truthy(text:find("professions ?", 1, true))
		assert.truthy(text:find("trees ?", 1, true))
		assert.truthy(text:find("B-R", 1, true))
	end)

	it("dates a part carried over from an earlier snapshot", function()
		local ns = loadStack()
		local Model = ns.Model
		local function snapshot(professionsReason, now)
			local character = fixture("dump_character_shaman").character
			character.professions = professionsReason == nil
				and { { name = "Alchemy", skillLineId = 171, skill = 120, max = 150 } } or nil -- derived
			character.professionsReason = professionsReason
			return Model.BuildSnapshot({ character = character,
				treeSpend = fixture("dump_trees_fresh").treeSpend, now = now })
		end
		local merged = Model.MergeSnapshot(snapshot(nil, 1000),
			snapshot("GetProfessions unavailable", 1000 + 3600))

		local text = ns.Debug.RenderRoster({ roster = Model.Roster({ merged }, merged.key), now = 1000 + 3600 })

		assert.truthy(text:find("L1 Shaman  0m ago", 1, true))
		assert.truthy(text:find("Alchemy 120/150 [171]  (kept from 60m ago: GetProfessions unavailable)", 1, true))
		assert.truthy(text:find("unspent 0, cap 16\n", 1, true))
	end)

	it("marks a skill-line answer that came from the saved map", function()
		local ns = loadStack()
		local challenges = fixture("dump_challenges_page1_fresh").challenges
		local parents = ns.Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)

		local text = ns.Debug.RenderRoster({ roster = ns.Model.Roster({}, nil), parents = parents,
			candidates = ns.Model.ProfessionCandidates(challenges, {}, parents) })

		assert.truthy(text:find("[line 2937, parent 171, profession nil, saved]  need 150", 1, true))
		assert.truthy(text:find("no stored character has this profession", 1, true))
	end)

	it("tells a failed challenge read apart from no tradeskill challenges", function()
		local ns = loadStack()
		local roster = ns.Model.Roster({}, nil)

		local failed = ns.Debug.RenderRoster({ roster = roster, candidates = {},
			challengesReason = "categories: GetCategoryList unavailable" })
		local empty = ns.Debug.RenderRoster({ roster = roster, candidates = {} })

		assert.truthy(failed:find("challenge read failed: categories: GetCategoryList unavailable", 1, true))
		assert.is_nil(failed:find("no incomplete tradeskill challenges", 1, true))
		assert.truthy(empty:find("no incomplete tradeskill challenges", 1, true))
	end)
end)
