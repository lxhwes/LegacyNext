local helper = require("spec.spec_helper")

-- Debug.RenderView is the text form of the v0 frame. It is rendered here against captured
-- fixtures and compared to a golden file, so a change in row content shows up as a diff in
-- this suite rather than as a screenshot from Alex.
local function loadStack()
	local ns = helper.loadAddonFile("LegacyNext/Model/Model.lua")
	helper.loadAddonFile("LegacyNext/Debug/Debug.lua", ns)
	return ns
end

local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

local function combinedChallenges()
	local list = {}
	for _, challenge in ipairs(fixture("dump_challenges_page1_fresh").challenges) do
		list[#list + 1] = challenge
	end
	local types = fixture("dump_criteria_types")
	for _, key in ipairs({ "dungeons", "reputation", "seasonJourney", "raid", "partiallyDone", "explorerMeta" }) do
		list[#list + 1] = types[key]
	end
	return list
end

-- UPDATE_GOLDEN=1 rewrites the golden file from the current output instead of comparing.
-- For a deliberate change to row content only: read `git diff spec/golden/` before committing.
local function writeFile(path, text)
	local handle = assert(io.open(path, "w"))
	handle:write(text)
	handle:close()
end

local function readFile(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- Line-by-line so a failure names the first differing line instead of dumping both files.
local function assertSameText(expected, actual)
	local expectedLines, actualLines = {}, {}
	for line in (expected .. "\n"):gmatch("(.-)\n") do expectedLines[#expectedLines + 1] = line end
	for line in (actual .. "\n"):gmatch("(.-)\n") do actualLines[#actualLines + 1] = line end
	for index = 1, math.max(#expectedLines, #actualLines) do
		if expectedLines[index] ~= actualLines[index] then
			error(("line %d differs\nexpected: %s\nactual:   %s"):format(
				index, tostring(expectedLines[index]), tostring(actualLines[index])), 2)
		end
	end
end

describe("Debug.RenderView", function()
	it("matches the golden uidump for page 1 plus the criteria-type excerpts", function()
		local ns = loadStack()
		local view = ns.Model.BuildView({
			challenges = combinedChallenges(),
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
			categories = fixture("categories_full").categories,
			character = fixture("dump_character_shaman").character,
		})
		local text = ns.Debug.RenderView(view,
			"fixtures: page1 + criteria types + categories_full + rewards_fresh + character_shaman")

		local golden = "spec/golden/uidump_combined.txt"
		if os.getenv("UPDATE_GOLDEN") == "1" then
			writeFile(golden, text)
		end
		assertSameText(readFile(golden), text)
	end)

	it("says how many other-class rows were hidden", function()
		local ns = loadStack()
		local view = ns.Model.BuildView({
			challenges = combinedChallenges(),
			categories = fixture("categories_full").categories,
			character = fixture("dump_character_shaman").character,
		})
		local text = ns.Debug.RenderView(view)

		assert.matches("note=3 other%-class challenges hidden", text)
		assert.matches("otherClass=3", text)
	end)

	it("renders the error state without a row block", function()
		local ns = loadStack()
		local view = ns.Model.BuildView({
			challenges = nil,
			challengesReason = "GetCategoryList unavailable",
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
		})
		local text = ns.Debug.RenderView(view)

		assert.matches("== ROWS %(0%) ==", text)
		assert.matches("state=error  Could not read your challenges: GetCategoryList unavailable", text)
		assert.matches("Next: Replica Ironforge Air Rifle", text)
	end)

	it("marks the selected filter and reports names that overflow", function()
		local ns = loadStack()
		local categories = fixture("categories_full").categories
		local classes
		for _, category in ipairs(categories) do
			if category.name == "Classes" then classes = category.id end
		end
		local view = ns.Model.BuildView({
			challenges = combinedChallenges(),
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
			categories = categories,
			filter = classes,
		})
		local text = ns.Debug.RenderView(view)

		assert.matches("All 16 | %[Classes 3%]", text)
		assert.matches("== ROWS %(4%) ==", text) -- three Druid rows plus the divider
		assert.matches("names over 30 chars: 0", text)
	end)

	it("matches the golden uidump for the roster tab", function()
		local ns = loadStack()
		helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
		local Model = ns.Model
		local shaman = Model.BuildSnapshot({
			character = fixture("dump_character_shaman").character,
			treeSpend = fixture("dump_trees_fresh").treeSpend,
			now = 1000,
		})
		-- Model's own snapshot shape with derived values: no captured character knows a
		-- profession yet (D4), and 2937 -> 171 is the DB2 reading, not a live answer (S1).
		local zug = { key = "Zug-Classic Beta PvP", name = "Zug", realm = "Classic Beta PvP", class = "Druid",
			level = 30, takenAt = 1000 - 7200, professionsAt = 1000 - 7200,
			professions = { { name = "Alchemy", skillLineId = 171, skill = 140, max = 150 } } }
		local parents = Model.MergeSkillLineParents({ [2937] = { parentId = 171 } }, nil)
		local snapshots = { zug, shaman }
		local view = Model.BuildRosterView({
			snapshots = snapshots,
			currentKey = shaman.key,
			now = 1000 + 600,
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
			candidates = Model.ProfessionCandidates(combinedChallenges(), snapshots, parents),
		})
		local text = ns.Debug.RenderView(view,
			"fixtures: character_shaman + trees_fresh + derived Zug + page1 + criteria types + rewards_fresh")

		local golden = "spec/golden/uidump_roster.txt"
		if os.getenv("UPDATE_GOLDEN") == "1" then
			writeFile(golden, text)
		end
		assertSameText(readFile(golden), text)
	end)

	-- U4, 2026-10-01: the same login's /lgn uidump roster, kept verbatim in
	-- roster_geo_restart.lua. Page 1 holds only the three Alchemy challenges and the other 15
	-- tradeskill challenges were never captured, so the footnote's note line cannot be
	-- reproduced whole. Everything else from the header to the end of STATE is compared, and
	-- the note's wording is checked separately below.
	local function capturedUidump()
		return assert(readFile("spec/fixtures/roster_geo_restart.lua")
			:match("%-%-%[==%[ /lgn uidump roster, same login, verbatim:\n(.-)\n%]==%]"))
	end

	local function captureView(ns, snapshots, currentKey)
		return ns.Model.BuildRosterView({
			snapshots = snapshots,
			currentKey = currentKey,
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
			candidates = ns.Model.ProfessionCandidates(fixture("dump_challenges_page1_fresh").challenges,
				snapshots, fixture("roster_geo_restart").parents),
		})
	end

	it("reproduces the captured roster tab from the captured snapshots", function()
		local ns = loadStack()
		helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
		local captured = fixture("roster_geo_restart")
		local view = captureView(ns, captured.snapshots, "Geo-Classic Beta PvP")

		local function headerToState(text)
			-- RenderView has no CLIENT section; the capture's comes from the frame.
			local block = assert((text:gsub("\n$", "") .. "\n== CLIENT =="):match("(== HEADER.-)\n== CLIENT =="))
			return (block:gsub("\nnote=[^\n]*", ""))
		end
		assertSameText(headerToState(capturedUidump()), headerToState(ns.Debug.RenderView(view)))
	end)

	-- Bong alone has none of page 1's professions, so the note renders; only its count differs.
	it("words the footnote as the captured roster tab does", function()
		local ns = loadStack()
		helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
		local bong = {}
		for _, snapshot in ipairs(fixture("roster_geo_restart").snapshots) do
			if snapshot.key ~= "Geo-Classic Beta PvP" then
				bong[#bong + 1] = snapshot
			end
		end

		local function note(text)
			return (assert(text:match("\nnote=([^\n]*)")):gsub("^%d+ ", "N "))
		end
		assert.equals(note(capturedUidump()), note(ns.Debug.RenderView(captureView(ns, bong))))
	end)
end)
