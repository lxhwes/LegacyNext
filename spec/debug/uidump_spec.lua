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
		})
		local text = ns.Debug.RenderView(view,
			"fixtures: page1 + criteria types + categories_full + rewards_fresh")

		assertSameText(readFile("spec/golden/uidump_combined.txt"), text)
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
end)
