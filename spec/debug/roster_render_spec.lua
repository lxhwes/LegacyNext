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
				loadedCharacters = 1, sessions = 3, characters = 1 },
			parentsReason = "2937: missing",
			now = 1000 + 600,
		})

		assert.truthy(text:find("sessions=3 characters=1", 1, true))
		assert.truthy(text:find("* Bong Wrip-Classic Beta PvP  L1 Shaman  10m ago", 1, true))
		assert.truthy(text:find("Professions 0, Adventure 0, Resourcefulness 0 | unspent 0, cap 16", 1, true))
		assert.truthy(text:find("no professions", 1, true))
		assert.truthy(text:find("parent lookup: 2937: missing", 1, true))
		assert.truthy(text:find("Journeyman Alchemist  [line 2937, parent nil]  need 150", 1, true))
		assert.truthy(text:find("no stored character has this profession", 1, true))
	end)

	it("says when a part of a snapshot was never read", function()
		local ns = loadStack()
		local roster = ns.Model.Roster({ { key = "A-R", level = 5, class = "Druid" } }, nil)

		local text = ns.Debug.RenderRoster({ roster = roster, diagnostics = { readOnly = true,
			reason = "saved schema 2" }, eventsNotRegistered = { "TRAIT_CONFIG_UPDATED (unknown to this client)" } })

		assert.truthy(text:find("READ ONLY: saved schema 2", 1, true))
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
end)
