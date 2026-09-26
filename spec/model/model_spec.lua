local helper = require("spec.spec_helper")

-- Model/ is pure Lua. Every test here loads it under an environment that errors on any global
-- outside the Lua 5.1 standard library, so the "no WoW globals" rule is enforced at call time
-- and not only at load time.
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
	local chunk = assert(loadfile("LegacyNext/Model/Model.lua"))
	setfenv(chunk, strictEnv())
	chunk("LegacyNext", ns)
	return ns.Model
end

local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = deepCopy(item)
	end
	return out
end

local function byName(list, name)
	for _, item in ipairs(list) do
		if item.name == name then
			return item
		end
	end
	error("no entry named " .. name)
end

local function names(entries)
	local out = {}
	for index, entry in ipairs(entries) do
		out[index] = entry.challenge and entry.challenge.name or entry.name
	end
	return out
end

-- Page 1 plus the criteria-type excerpts, as one challenge list.
local function combinedChallenges()
	local page1 = fixture("dump_challenges_page1_fresh").challenges
	local types = fixture("dump_criteria_types")
	local list = deepCopy(page1)
	for _, key in ipairs({ "dungeons", "reputation", "seasonJourney", "raid", "partiallyDone", "explorerMeta" }) do
		list[#list + 1] = deepCopy(types[key])
	end
	return list
end

describe("Model", function()
	it("loads and runs with no WoW globals present", function()
		local Model = loadModel()
		assert.is_table(Model)

		-- Exercise every entry point under the strict environment, not just the load.
		local view = Model.BuildView({
			challenges = combinedChallenges(),
			rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
			categories = fixture("categories_full").categories,
		})
		assert.equals("ok", view.state)
	end)

	it("is loaded by the plain helper too, as the client would", function()
		local ns = helper.loadAddonFile("LegacyNext/Model/Model.lua")
		assert.is_function(ns.Model.BuildView)
	end)

	describe("Progress", function()
		local Model = loadModel()
		local page1 = fixture("dump_challenges_page1_fresh").challenges
		local types = fixture("dump_criteria_types")

		it("marks a challenge with no criteria as measureless", function()
			local progress = Model.Progress(byName(page1, "Novice Druid"))
			assert.is_false(progress.measurable)
			assert.equals("no criteria", progress.reason)
		end)

		it("reads a single progress-bar criterion as have/need", function()
			local progress = Model.Progress(byName(page1, "Journeyman Alchemist"))
			assert.is_true(progress.measurable)
			assert.equals(0, progress.have)
			assert.equals(150, progress.need)
			assert.equals(0, progress.fraction)
			assert.equals(1, progress.criteriaLeft)
			assert.is_false(progress.started)
		end)

		it("uses need/have on a type-243 criterion whose progress-bar bit is clear", function()
			-- The D7 trap: flags 1024, isProgressBar false, need 42000. A checklist reading
			-- would call this 0/1.
			local progress = Model.Progress(types.reputation)
			assert.is_true(progress.measurable)
			assert.equals(0, progress.have)
			assert.equals(42000, progress.need)
			assert.equals(1, progress.criteriaLeft)
		end)

		it("reads a full checklist as done/total", function()
			local progress = Model.Progress(byName(page1, "Explore Alterac Mountains"))
			assert.is_true(progress.measurable)
			assert.equals(0, progress.have)
			assert.equals(15, progress.need)
			assert.equals(15, progress.criteriaTotal)
		end)

		it("counts a completed criterion in a checklist", function()
			-- Explore Durotar is captured as an excerpt (2 of 11 criteria), so the list is
			-- padded back to its captured count with copies of its own incomplete row to make
			-- the checklist whole. Shape is untouched; only the count is restored.
			local challenge = deepCopy(types.partiallyDone)
			while #challenge.criteria < challenge.criteriaExpected do
				challenge.criteria[#challenge.criteria + 1] = deepCopy(challenge.criteria[2])
			end
			local progress = Model.Progress(challenge)
			assert.is_true(progress.measurable)
			assert.equals(1, progress.have)
			assert.equals(11, progress.need)
			assert.equals(1, progress.criteriaDone)
			assert.equals(10, progress.criteriaLeft)
			assert.is_true(progress.started)
			assert.is_true(progress.fraction > 0.09 and progress.fraction < 0.1)
		end)

		it("refuses to score a criteria list that came back short", function()
			-- The excerpt carries 3 of the 6 criteria the client reported.
			local progress = Model.Progress(types.dungeons)
			assert.is_false(progress.measurable)
			assert.equals("partial read", progress.reason)
			assert.equals(3, progress.criteriaRead)
			assert.equals(6, progress.criteriaTotal)
		end)

		it("clamps a have that overshoots need", function()
			local challenge = deepCopy(byName(page1, "Expert Alchemist"))
			challenge.criteria[1].have = 999 -- derived: captured 0, varied to test clamping
			local progress = Model.Progress(challenge)
			assert.equals(225, progress.have)
			assert.equals(1, progress.fraction)
		end)
	end)

	describe("Rank", function()
		local Model = loadModel()

		it("excludes zero-point and completed challenges, keeps unknown points", function()
			local list = deepCopy(fixture("dump_challenges_page1_fresh").challenges)
			byName(list, "Rank 14").completed = true -- derived: captured false, varied
			byName(list, "Rank 13").points = nil -- derived: captured 1, varied to a failed read

			local entries, stats = Model.Rank(list)
			assert.equals(20, stats.total)
			assert.equals(9, stats.zeroPoint)
			assert.equals(1, stats.completed)
			assert.equals(10, stats.ranked)
			assert.equals(1, stats.pointsUnknown)
			assert.equals(10, #entries)
			for _, entry in ipairs(entries) do
				assert.is_not_equal("Rank 14", entry.challenge.name)
				assert.is_not_equal(0, entry.challenge.points)
			end
		end)

		it("keeps untouched and measureless challenges in client order", function()
			local entries, stats = Model.Rank(fixture("dump_challenges_page1_fresh").challenges)
			assert.equals(3, stats.measurable)
			assert.equals(8, stats.measureless)
			assert.same({
				"Journeyman Alchemist", "Expert Alchemist", "Artisan Alchemist",
				"Novice Druid", "Experienced Druid", "Master Druid",
				"Rank 3", "Rank 7", "Rank 10", "Rank 13", "Rank 14",
			}, names(entries))
		end)

		it("puts partial progress ahead of untouched, by fraction", function()
			local list = deepCopy(fixture("dump_challenges_page1_fresh").challenges)
			byName(list, "Artisan Alchemist").criteria[1].have = 290 -- derived: captured 0
			byName(list, "Journeyman Alchemist").criteria[1].have = 75 -- derived: captured 0

			local entries = Model.Rank(list)
			assert.same(
				{ "Artisan Alchemist", "Journeyman Alchemist", "Expert Alchemist" },
				{ names(entries)[1], names(entries)[2], names(entries)[3] }
			)
		end)

		-- Superseded 2026-09-26: untouched challenges used to tiebreak on raw units remaining,
		-- which put Explorer (one type-8 step, the whole map underneath) first on a fresh
		-- character. Untouched now means "no closeness signal", so client order stands.
		it("never ranks an untouched challenge as close, so Explorer is not first", function()
			local entries = Model.Rank(combinedChallenges())
			local notStarted = {}
			for _, entry in ipairs(entries) do
				assert.is_not_equal(1, entry.tier) -- nothing captured is part-done and point-bearing
				if entry.tier == 2 then
					notStarted[#notStarted + 1] = entry.challenge.name
				end
			end
			assert.same({
				"Journeyman Alchemist", "Expert Alchemist", "Artisan Alchemist",
				"Master of Alterac Valley", "Field of Honor: Week 4", "Explorer",
			}, notStarted)
		end)

		it("breaks a fraction tie in progress by client order", function()
			local list = deepCopy(fixture("dump_challenges_page1_fresh").challenges)
			byName(list, "Artisan Alchemist").criteria[1].have = 150 -- derived: captured 0
			byName(list, "Journeyman Alchemist").criteria[1].have = 75 -- derived: captured 0

			local entries = Model.Rank(list)
			assert.same({ "Journeyman Alchemist", "Artisan Alchemist" }, { names(entries)[1], names(entries)[2] })
			assert.equals(1, entries[1].tier)
			assert.equals(1, entries[2].tier)
			assert.equals(2, entries[3].tier)
		end)

		it("does not let 0/42000 reputation outrank 0/150 skill", function()
			local entries = Model.Rank(combinedChallenges())
			local order = names(entries)
			local skill, reputation
			for index, name in ipairs(order) do
				if name == "Journeyman Alchemist" then skill = index end
				if name == "Master of Alterac Valley" then reputation = index end
			end
			assert.is_true(skill < reputation)
			-- And it is still measurable: it sits above the measureless block.
			local avEntry
			for _, entry in ipairs(entries) do
				if entry.challenge.name == "Master of Alterac Valley" then avEntry = entry end
			end
			assert.is_true(avEntry.progress.measurable)
		end)

		it("sorts partial reads with the measureless block, flagged", function()
			local entries, stats = Model.Rank(combinedChallenges())
			assert.equals(2, stats.partialRead) -- Novice Spelunker (3/6), Conquerer of the Wilds (2/13)
			local firstMeasureless
			for index, entry in ipairs(entries) do
				if not entry.progress.measurable then
					firstMeasureless = index
					break
				end
			end
			for index = firstMeasureless, #entries do
				assert.is_false(entries[index].progress.measurable)
			end
		end)
	end)

	describe("Groups", function()
		local Model = loadModel()

		it("treats parentCategoryId -1 as top level and names groups from the category list", function()
			local entries = Model.Rank(combinedChallenges())
			local groups = Model.Groups(entries, fixture("categories_full").categories)

			local labels, counts = {}, {}
			for index, group in ipairs(groups) do
				labels[index] = group.name
				counts[group.name] = group.count
			end
			assert.same(
				{ "Classes", "Tradeskills", "Dungeons", "Raids", "Player vs. Player", "Adventure" },
				labels
			)
			assert.equals(3, counts["Classes"])
			assert.equals(3, counts["Tradeskills"])
			assert.equals(1, counts["Dungeons"])
			assert.equals(1, counts["Raids"])
			assert.equals(7, counts["Player vs. Player"])
			assert.equals(1, counts["Adventure"]) -- Explorer, the point-bearing meta
		end)

		it("never shows an empty category", function()
			local entries = Model.Rank(combinedChallenges())
			local groups = Model.Groups(entries, fixture("categories_full").categories)
			for _, group in ipairs(groups) do
				assert.is_not_equal("Do Not Display", group.name)
				assert.is_not_equal("Tier 1 Gear", group.name)
				assert.is_true(group.count > 0)
			end
		end)

		it("falls back to an id label when the category list is missing", function()
			local entries = Model.Rank(fixture("dump_challenges_page1_fresh").challenges)
			local groups = Model.Groups(entries, nil)
			assert.equals(3, #groups) -- Classes, Tradeskills, Player vs. Player
			assert.matches("^Category %d+$", groups[1].name) -- Classes has no challenges of its own
			assert.equals(3, groups[1].count)
		end)

		it("filters to one group", function()
			local entries = Model.Rank(combinedChallenges())
			local groups = Model.Groups(entries, fixture("categories_full").categories)
			local pvp = byName(groups, "Player vs. Player")
			local filtered = Model.Filter(entries, pvp.id)
			assert.equals(7, #filtered)
			for _, entry in ipairs(filtered) do
				assert.equals(pvp.id, entry.groupId)
			end
			assert.equals(#entries, #Model.Filter(entries, nil))
		end)
	end)

	describe("RewardSummary", function()
		local Model = loadModel()
		local track = fixture("dump_rewards_fresh").rewardTrack

		it("reads the fresh track: 0 points, 15 to the air rifle", function()
			local summary = Model.RewardSummary(track)
			assert.equals("Legacy Track", summary.name)
			assert.equals(0, summary.earned)
			assert.equals(15, summary.nextThreshold)
			assert.equals(15, summary.pointsToNext)
			assert.same({ "Replica Ironforge Air Rifle" }, summary.nextRewardNames)
			assert.equals(0, summary.thresholdsReached)
			assert.equals(4, summary.thresholdsTotal)
			assert.is_false(summary.complete)
		end)

		it("recomputes the next threshold from the sparse list", function()
			local varied = deepCopy(track)
			varied.earned, varied.level = 20, 20 -- derived: captured 0, varied to test the math
			local summary = Model.RewardSummary(varied)
			assert.equals(25, summary.nextThreshold)
			assert.equals(5, summary.pointsToNext)
			assert.same({ "Spectral Bear Cub" }, summary.nextRewardNames)
			assert.equals(1, summary.thresholdsReached)
		end)

		it("reports a finished track", function()
			local varied = deepCopy(track)
			varied.earned, varied.level = 60, 60 -- derived: captured 0, varied
			local summary = Model.RewardSummary(varied)
			assert.is_nil(summary.nextThreshold)
			assert.is_true(summary.complete)
			assert.equals(4, summary.thresholdsReached)
		end)

		it("ignores isCollected entirely", function()
			-- The level 40 tabard reads isCollected = true on an unreached tier.
			local summary = Model.RewardSummary(track)
			assert.equals(0, summary.thresholdsReached)
		end)

		it("returns nil plus a reason for a missing track", function()
			local summary, reason = Model.RewardSummary(nil)
			assert.is_nil(summary)
			assert.equals("no reward track", reason)
		end)
	end)

	describe("BuildView", function()
		local Model = loadModel()

		-- Pass `false` to remove a field; pairs() cannot carry a nil.
		local function input(overrides)
			local base = {
				challenges = combinedChallenges(),
				rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
				categories = fixture("categories_full").categories,
			}
			for key, value in pairs(overrides or {}) do
				if value == false then
					base[key] = nil
				else
					base[key] = value
				end
			end
			return base
		end

		it("renders the header from the reward summary", function()
			local view = Model.BuildView(input())
			assert.equals("ok", view.header.state)
			assert.equals("Legacy Track" .. Model.SEPARATOR .. "0 pts" .. Model.SEPARATOR .. "15 to next",
				view.header.lines[1])
			assert.equals("Next: Replica Ironforge Air Rifle", view.header.lines[2])
		end)

		it("keeps a reward-track failure separate from the list", function()
			local view = Model.BuildView(input({ rewardTrack = false, rewardTrackReason = "GetMajorFactionData unavailable" }))
			assert.equals("error", view.header.state)
			assert.matches("GetMajorFactionData unavailable", view.header.lines[2])
			assert.equals("ok", view.state)
			assert.is_true(#view.rows > 0)
		end)

		local function dividerTexts(view)
			local out = {}
			for _, row in ipairs(view.rows) do
				if row.kind == "divider" then
					out[#out + 1] = row.text
				end
			end
			return out
		end

		it("labels each tier present with its own divider, opening with not started when fresh", function()
			local view = Model.BuildView(input())
			assert.same({ Model.TIER_TEXT[2], Model.TIER_TEXT[3] }, dividerTexts(view))
			assert.equals("divider", view.rows[1].kind)

			local tier = 0
			for _, row in ipairs(view.rows) do
				if row.kind == "divider" then
					tier = tier + 1
				elseif tier == 1 then
					assert.is_true(row.measurable)
				else
					assert.is_false(row.measurable)
				end
			end
		end)

		it("adds an in progress tier above the rest once anything is part-done", function()
			local challenges = combinedChallenges()
			byName(challenges, "Expert Alchemist").criteria[1].have = 10 -- derived: captured 0
			local view = Model.BuildView(input({ challenges = challenges }))
			assert.same({ Model.TIER_TEXT[1], Model.TIER_TEXT[2], Model.TIER_TEXT[3] }, dividerTexts(view))
			assert.equals("Expert Alchemist", view.rows[2].name)
			assert.equals("10/225", view.rows[2].progressText)
		end)

		describe("other-class challenges", function()
			local shaman = fixture("dump_character_shaman").character

			it("hides the other classes' rows for the current character and says how many", function()
				local view = Model.BuildView(input({ character = shaman }))
				for _, row in ipairs(view.rows) do
					assert.is_not_equal("Druid", row.category)
				end
				assert.equals(3, view.stats.otherClass)
				assert.equals("3 other-class challenges hidden", view.footnote)
				assert.equals(13, view.filters[1].count)
				for _, filter in ipairs(view.filters) do
					assert.is_not_equal("Classes", filter.name) -- only Druid rows on these fixtures
				end
			end)

			it("keeps the character's own class", function()
				local druid = deepCopy(shaman)
				druid.class = "Druid" -- derived: captured Shaman, varied to own the Druid rows
				local view = Model.BuildView(input({ character = druid }))
				assert.equals(0, view.stats.otherClass)
				assert.is_nil(view.footnote)
				assert.equals(16, view.filters[1].count)
			end)

			it("hides nothing when the class name matches no category", function()
				local other = deepCopy(shaman)
				other.class = "Chamane" -- derived: a locale the category names are not in
				local view = Model.BuildView(input({ character = other }))
				assert.equals(0, view.stats.otherClass)
				assert.equals(16, view.filters[1].count)
			end)

			it("hides nothing without a character or a category list", function()
				assert.equals(16, Model.BuildView(input()).filters[1].count)
				assert.equals(16, Model.BuildView(input({ character = shaman, categories = false })).filters[1].count)
			end)

			it("finds the sibling classes by structure, not by the parent's name", function()
				local categories = fixture("categories_full").categories
				local hidden = Model.OtherClassCategories(categories, "Shaman")
				local shamanCategory = byName(categories, "Shaman")
				local expected = 0
				for _, category in ipairs(categories) do
					if category.parentId == shamanCategory.parentId and category.id ~= shamanCategory.id then
						expected = expected + 1
						assert.is_true(hidden[category.id])
					end
				end
				assert.is_nil(hidden[shamanCategory.id])
				assert.is_true(expected >= 8)
			end)
		end)

		it("formats row text", function()
			local view = Model.BuildView(input())
			local rows = {}
			for _, row in ipairs(view.rows) do
				if row.kind == "challenge" then
					rows[row.name] = row
				end
			end
			assert.equals("0/150", rows["Journeyman Alchemist"].progressText)
			assert.equals("1pt", rows["Journeyman Alchemist"].pointsText)
			assert.equals("0/42000", rows["Master of Alterac Valley"].progressText)
			assert.equals("", rows["Novice Druid"].progressText)
			assert.equals("?", rows["Novice Spelunker"].progressText)
			assert.is_true(#rows["Master of Alterac Valley"].detail >= 2)
			assert.matches("%[ %] Reach exalted reputation with the Frostwolf Clan 0/42000",
				rows["Master of Alterac Valley"].detail[2])
		end)

		it("builds the filter bar with All selected by default", function()
			local view = Model.BuildView(input())
			assert.equals("All", view.filters[1].name)
			assert.is_true(view.filters[1].selected)
			assert.equals(16, view.filters[1].count) -- 11 from page 1 + 5 point-bearing excerpts
			assert.equals(7, #view.filters)
		end)

		it("applies a filter and falls back to All on an unknown id", function()
			local classes = byName(fixture("categories_full").categories, "Classes")
			local view = Model.BuildView(input({ filter = classes.id }))
			assert.equals(classes.id, view.filter)
			assert.is_true(byName(view.filters, "Classes").selected)
			assert.is_false(view.filters[1].selected)
			local count = 0
			for _, row in ipairs(view.rows) do
				if row.kind == "challenge" then
					count = count + 1
					assert.equals("Druid", row.category)
				end
			end
			assert.equals(3, count)

			local fallback = Model.BuildView(input({ filter = 1 }))
			assert.is_nil(fallback.filter)
			assert.is_true(fallback.filters[1].selected)
		end)

		it("says error, empty and done differently", function()
			local err = Model.BuildView(input({ challenges = false, challengesReason = "GetCategoryList unavailable" }))
			assert.equals("error", err.state)
			assert.equals("Could not read your challenges: GetCategoryList unavailable", err.message)

			local empty = Model.BuildView(input({ challenges = {} }))
			assert.equals("empty", empty.state)
			assert.equals("No Legacy challenges found", empty.message)

			local allDone = deepCopy(fixture("dump_challenges_page1_fresh").challenges)
			for _, challenge in ipairs(allDone) do
				challenge.completed = true -- derived: captured false, varied
			end
			local done = Model.BuildView(input({ challenges = allDone }))
			assert.equals("done", done.state)
			assert.equals("Nothing left to earn", done.message)
			assert.equals(0, #done.rows)
		end)
	end)
end)
