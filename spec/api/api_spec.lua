local helper = require("spec.spec_helper")

-- These exercise the guard layer itself, not any Blizzard response shape. The stub functions
-- below return deliberately trivial values; no captured fixture is being asserted here.
local function loadApi()
	return helper.loadAddonFile("LegacyNext/Api/Api.lua")
end

describe("Api", function()
	local injected = {}

	local function inject(name, value)
		injected[#injected + 1] = name
		_G[name] = value
	end

	after_each(function()
		for _, name in ipairs(injected) do
			_G[name] = nil
		end
		injected = {}
	end)

	it("loads without touching WoW globals", function()
		local ns = loadApi()

		assert.is_table(ns.Api)
	end)

	it("keeps both unresolved-question flags off", function()
		local ns = loadApi()

		assert.is_false(ns.Api.flags.eventDrivenRefresh)
		assert.is_false(ns.Api.flags.followMetaChains)
	end)

	describe("HasFlag", function()
		it("reads a single bit out of a bitfield", function()
			local Api = loadApi().Api

			-- 134349824 is the live flags value on a point-bearing challenge; 131072 is
			-- ACHIEVEMENT_FLAGS_ACCOUNT. Both captured in game 2026-09-18.
			assert.is_true(Api.HasFlag(134349824, 131072))
			assert.is_false(Api.HasFlag(0, 131072))
			assert.is_true(Api.HasFlag(1, 1))
			assert.is_false(Api.HasFlag(2, 1))
		end)

		it("is false rather than an error on junk input", function()
			local Api = loadApi().Api

			assert.is_false(Api.HasFlag(nil, 1))
			assert.is_false(Api.HasFlag(1, nil))
			assert.is_false(Api.HasFlag("1", 1))
		end)
	end)

	describe("Resolve", function()
		it("finds a dotted path", function()
			local Api = loadApi().Api
			inject("LegacyNextFakeNamespace", { Nested = { value = 7 } })

			assert.equals(7, Api.Resolve("LegacyNextFakeNamespace.Nested.value"))
		end)

		it("returns nil instead of indexing a missing namespace", function()
			local Api = loadApi().Api

			assert.is_nil(Api.Resolve("LegacyNextMissing.Thing"))
		end)
	end)

	describe("PlainCopy", function()
		it("copies rather than handing back the client's table", function()
			local Api = loadApi().Api
			local source = { a = 1, nested = { b = 2 } }

			local copy = Api.PlainCopy(source)

			assert.are_not_equal(source, copy)
			assert.are_not_equal(source.nested, copy.nested)
			assert.same(source, copy)
		end)

		it("drops a cyclic field and keeps the rest of the table", function()
			local Api = loadApi().Api
			local source = { name = "Legacy Track" }
			source.self = source

			local copy, reason, dropped = Api.PlainCopy(source)

			assert.is_nil(reason)
			assert.equals("Legacy Track", copy.name)
			assert.is_nil(copy.self)
			assert.equals(1, #dropped)
			assert.truthy(dropped[1]:find("cyclic", 1, true))
		end)

		-- The real case: MajorFactionData.factionFontColor is a DBColorExport whose `color`
		-- carries ColorMixin, so the client hands us methods two levels down inside a struct
		-- of otherwise ordinary scalars.
		it("drops a mixed-in method without losing the scalars beside it", function()
			local Api = loadApi().Api
			local source = {
				name = "Legacy Track",
				maxLevel = 90,
				factionFontColor = {
					baseTag = "legacy",
					color = { r = 1, g = 1, b = 1, GetRGB = function() return 1, 1, 1 end },
				},
			}

			local copy, reason, dropped = Api.PlainCopy(source)

			assert.is_nil(reason)
			assert.equals("Legacy Track", copy.name)
			assert.equals(90, copy.maxLevel)
			assert.equals(1, copy.factionFontColor.color.r)
			assert.is_nil(copy.factionFontColor.color.GetRGB)
			assert.equals(1, #dropped)
			assert.truthy(dropped[1]:find("GetRGB", 1, true))
			assert.truthy(dropped[1]:find("unsupported type function", 1, true))
		end)

		it("still refuses a function handed back as the value itself", function()
			local Api = loadApi().Api

			local copy, reason = Api.PlainCopy(function() end)

			assert.is_nil(copy)
			assert.equals("unsupported type function", reason)
		end)

		it("refuses a value the secret guard flags", function()
			local Api = loadApi().Api
			local secret = {}
			inject("issecretvalue", function(value) return value == secret end)

			local copy, reason = Api.PlainCopy({ field = secret })

			assert.is_nil(copy)
			assert.equals("secret", reason)
		end)
	end)

	describe("Call", function()
		it("packs returns so a nil return is distinguishable from a failure", function()
			local Api = loadApi().Api
			inject("LegacyNextStub", function() return nil, 2 end)

			local result = Api.Call("LegacyNextStub")

			assert.equals(2, result.n)
			assert.is_nil(result[1])
			assert.equals(2, result[2])
		end)

		it("reports a missing function without calling anything", function()
			local Api = loadApi().Api

			local result, reason = Api.Call("LegacyNextAbsent")

			assert.is_nil(result)
			assert.equals("missing", reason)
			assert.equals(1, Api.GetFailures()["LegacyNextAbsent"].missing)
		end)

		it("catches an error and tallies it", function()
			local Api = loadApi().Api
			inject("LegacyNextThrows", function() error("boom") end)

			local result, reason = Api.Call("LegacyNextThrows")

			assert.is_nil(result)
			assert.is_truthy(reason:match("^error"))

			local failures = Api.GetFailures()["LegacyNextThrows"]
			assert.equals(1, failures.errors)
			assert.is_truthy(failures.lastDetail:match("boom"))
		end)

		it("hands back a copy of a returned table", function()
			local Api = loadApi().Api
			local owned = { value = 1 }
			inject("LegacyNextReturnsTable", function() return owned end)

			local result = Api.Call("LegacyNextReturnsTable")

			assert.are_not_equal(owned, result[1])
			assert.equals(1, result[1].value)
		end)

		-- The first in-game run filed GetMajorFactionData under `secret` because its struct
		-- carries a mixin. `secret` is the one status that means Midnight's restrictions
		-- reached our surface, so it has to stay rare enough to be believed.
		it("counts a dropped field as a successful read, never as a secret", function()
			local Api = loadApi().Api
			inject("LegacyNextMixin", function()
				return { name = "Legacy Track", color = { GetRGB = function() end } }
			end)

			local result, reason, dropped = Api.Call("LegacyNextMixin")

			assert.is_nil(reason)
			assert.equals("Legacy Track", result[1].name)
			assert.equals(1, #dropped)

			local failures = Api.GetFailures()["LegacyNextMixin"]
			assert.equals(1, failures.ok)
			assert.equals(0, failures.secret)
			assert.equals(0, failures.errors)
			assert.equals(1, failures.partial)
			assert.is_truthy(failures.lastDropped:match("GetRGB"))
		end)

		it("still tallies a genuine secret as one", function()
			local Api = loadApi().Api
			local secret = {}
			inject("issecretvalue", function(value) return value == secret end)
			inject("LegacyNextSecret", function() return { field = secret } end)

			local result, reason = Api.Call("LegacyNextSecret")

			assert.is_nil(result)
			assert.equals("secret", reason)
			assert.equals(1, Api.GetFailures()["LegacyNextSecret"].secret)
		end)

		it("does not let the tally be mutated through the snapshot", function()
			local Api = loadApi().Api
			inject("LegacyNextStub", function() return true end)
			Api.Call("LegacyNextStub")

			local snapshot = Api.GetFailures()
			snapshot["LegacyNextStub"].ok = 99

			assert.equals(1, Api.GetFailures()["LegacyNextStub"].ok)
		end)
	end)

	describe("GetConstant", function()
		it("prefers the runtime table", function()
			local Api = loadApi().Api
			inject("Constants", { LegacyConsts = { LEGACY_POINTS_TRAIT_CURRENCY_ID = 999 } })

			local value, source = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")

			assert.equals(999, value)
			assert.equals("runtime", source)
		end)

		it("falls back to the verified literal and says so", function()
			local Api = loadApi().Api

			local value, source = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")

			assert.equals(4225, value)
			assert.equals("fallback", source)
		end)
	end)

	-- Enumeration contract, not response shapes. The stubs below return the minimum the guard
	-- needs to walk its own branches; nothing here asserts what the client really sends, and
	-- the real criteria fixtures still wait on a capture.
	describe("GetChallenges", function()
		it("returns an empty list, not a failure, when the categories hold nothing", function()
			local Api = loadApi().Api
			inject("GetCategoryList", function() return { 15586 } end)
			inject("GetCategoryInfo", function() return "Tradeskills", -1 end)
			inject("GetCategoryNumAchievements", function() return 0, 0, 0 end)

			local challenges, reason = Api.GetChallenges()

			-- The distinction that matters: worked-and-found-nothing must not arrive looking
			-- like a broken read, or the UI reports a bug instead of an empty frame.
			assert.same({}, challenges)
			assert.is_nil(reason)
		end)

		it("still fails when the category list itself is unavailable", function()
			local Api = loadApi().Api

			local challenges, reason = Api.GetChallenges()

			assert.is_nil(challenges)
			assert.is_truthy(reason)
		end)

		it("reports the criteria count so a short read is detectable", function()
			local Api = loadApi().Api
			inject("GetCategoryList", function() return { 15586 } end)
			inject("GetCategoryInfo", function() return "Tradeskills", -1 end)
			inject("GetCategoryNumAchievements", function() return 1, 0, 1 end)
			inject("GetAchievementInfo", function() return 62012, "Journeyman Alchemist" end)
			inject("GetAchievementNumCriteria", function() return 2 end)
			-- Second criterion read fails, so the list comes back one short of the count.
			inject("GetAchievementCriteriaInfo", function(_, index)
				if index == 2 then
					error("unavailable")
				end
				return "150 Alchemy Skill"
			end)

			local challenges = Api.GetChallenges()
			local challenge = challenges and challenges[1]

			assert.is_table(challenge)
			assert.equals(2, challenge.criteriaExpected)
			assert.equals(1, #challenge.criteria)
		end)

		it("distinguishes a challenge that genuinely has no criteria", function()
			local Api = loadApi().Api
			inject("GetCategoryList", function() return { 15586 } end)
			inject("GetCategoryInfo", function() return "Tradeskills", -1 end)
			inject("GetCategoryNumAchievements", function() return 1, 0, 1 end)
			inject("GetAchievementInfo", function() return 62100, "Warrior" end)
			inject("GetAchievementNumCriteria", function() return 0 end)

			local challenges = Api.GetChallenges()
			local challenge = challenges and challenges[1]

			assert.is_table(challenge)
			-- 34 of the 111 are binary. Zero expected and an empty list is the honest answer,
			-- and Model has to treat it as its own case rather than as 0%.
			assert.equals(0, challenge.criteriaExpected)
			assert.same({}, challenge.criteria)
		end)

		it("reuses a category list it is handed instead of reading it again", function()
			local Api = loadApi().Api
			-- No GetCategoryList, GetCategoryInfo or GetCategoryNumAchievements injected: a
			-- second read of any of them would fail this test.
			inject("GetAchievementInfo", function() return 62012, "Journeyman Alchemist" end)
			inject("GetAchievementNumCriteria", function() return 0 end)

			local challenges, reason = Api.GetChallenges({
				{ id = 15425, name = "Do Not Display", parentId = -1, numAchievements = 0 },
				{ id = 15587, name = "Alchemy", parentId = 15586, numAchievements = 1 },
			})

			assert.is_nil(reason)
			assert.equals(1, #challenges)
			assert.equals("Alchemy", challenges[1].categoryName)
			assert.equals(15586, challenges[1].parentCategoryId)
		end)
	end)

	describe("GetRewardTrack", function()
		it("skips list entries that are not tables instead of throwing", function()
			local Api = loadApi().Api
			inject("C_MajorFactions", {
				GetMajorFactionData = function() return { name = "Track", maxLevel = 90 } end,
				GetCurrentRenownLevel = function() return 0 end,
				GetRenownLevels = function() return { 7, { level = 15 } } end,
				GetRenownRewardsForLevel = function() return { "junk", { name = "Reward" } } end,
			})

			local track
			assert.has_no.errors(function() track = Api.GetRewardTrack() end)
			assert.equals(1, #track.thresholds)
			assert.equals(15, track.thresholds[1].level)
			assert.equals(1, #track.thresholds[1].rewards)
			assert.equals("Reward", track.thresholds[1].rewards[1].name)
		end)
	end)

	describe("GetCategories", function()
		it("returns nil plus the symbol that failed", function()
			local Api = loadApi().Api

			local categories, reason = Api.GetCategories()

			assert.is_nil(categories)
			assert.equals("GetCategoryList unavailable", reason)
		end)

		it("keeps empty categories and reports parent -1 untouched", function()
			local Api = loadApi().Api
			inject("GetCategoryList", function() return { 15425, 15568 } end)
			inject("GetCategoryInfo", function(id)
				if id == 15425 then return "Do Not Display", -1 end
				return "Classes", -1
			end)
			inject("GetCategoryNumAchievements", function() return 0, 0, 0 end)

			local categories = Api.GetCategories()

			-- Dropping the empty one is Model's job, by count. Api reports what the client said.
			assert.equals(2, #categories)
			assert.equals("Do Not Display", categories[1].name)
			assert.equals(-1, categories[1].parentId)
			assert.equals(0, categories[2].numAchievements)
		end)

		-- Queue row D9: the full /lgn dump categories capture, replayed through the globals it
		-- came from. What this pins is that Api preserves the client's order and drops nothing.
		it("round-trips the captured /lgn dump categories fixture", function()
			local captured = dofile("spec/fixtures/categories_full.lua").categories
			local byId, ids = {}, {}
			for index, category in ipairs(captured) do
				byId[category.id] = category
				ids[index] = category.id
			end

			local Api = loadApi().Api
			inject("GetCategoryList", function() return ids end)
			inject("GetCategoryInfo", function(id)
				return byId[id].name, byId[id].parentId, 0
			end)
			inject("GetCategoryNumAchievements", function(id)
				local c = byId[id]
				return c.numAchievements, c.numComplete, c.numIncomplete
			end)

			local categories = Api.GetCategories()

			assert.equals(29, #categories)
			local total = 0
			for index, category in ipairs(categories) do
				assert.equals(captured[index].id, category.id)
				assert.equals(captured[index].name, category.name)
				assert.equals(captured[index].parentId, category.parentId)
				assert.equals(captured[index].numAchievements, category.numAchievements)
				total = total + category.numAchievements
			end
			assert.equals(111, total)
		end)
	end)

	-- Trivial stubs in the GetProfessionInfo return order at Blizzard_ProfessionsFrame.lua:55
	-- (CLAUDE.md). No populated profession has been captured yet (D4).
	describe("GetCharacterInfo professions", function()
		it("names a slot whose GetProfessionInfo threw instead of returning a short list", function()
			local Api = loadApi().Api
			inject("UnitClass", function() return "Druid", "DRUID", 11 end)
			inject("GetProfessions", function() return 1, 2 end)
			inject("GetProfessionInfo", function(index)
				if index == 2 then
					error("boom")
				end
				return "one", 0, 10, 75, 0, 0, 100
			end)

			local character = Api.GetCharacterInfo()

			assert.equals(1, #character.professions)
			assert.equals(100, character.professions[1].skillLineId)
			assert.truthy(character.professionsReason:find("partial: slot 2: error", 1, true))
		end)

		it("gives no reason when every slot read", function()
			local Api = loadApi().Api
			inject("UnitClass", function() return "Druid", "DRUID", 11 end)
			inject("GetProfessions", function() return 1 end)
			inject("GetProfessionInfo", function() return "one", 0, 10, 75, 0, 0, 100 end)

			local character = Api.GetCharacterInfo()

			assert.equals(1, #character.professions)
			assert.is_nil(character.professionsReason)
		end)
	end)

	-- Trivial stubs: the guard on the roster key, not UnitGUID's shape.
	describe("GetCharacterInfo guid", function()
		local function character(guid)
			inject("UnitClass", function() return "Druid", "DRUID", 11 end)
			inject("UnitGUID", guid)
			return loadApi().Api.GetCharacterInfo()
		end

		it("reads the player's GUID", function()
			local asked
			local info = character(function(unit)
				asked = unit
				return "Player-1-00000001"
			end)

			assert.equals("player", asked)
			assert.equals("Player-1-00000001", info.guid)
			assert.is_nil(info.guidReason)
		end)

		it("still returns the character, with a reason, when UnitGUID is missing", function()
			local info = character(nil)

			assert.equals("Druid", info.class)
			assert.is_nil(info.guid)
			assert.equals("UnitGUID missing", info.guidReason)
		end)

		it("drops a secret GUID", function()
			local secret = "Player-1-00000001"
			inject("issecretvalue", function(value) return value == secret end)

			local info = character(function() return secret end)

			assert.is_nil(info.guid)
			assert.equals("UnitGUID secret", info.guidReason)
		end)

		it("drops a GUID that is not a non-empty string", function()
			assert.equals("UnitGUID returned an empty string", character(function() return "" end).guidReason)
			assert.equals("UnitGUID returned nil", character(function() return nil end).guidReason)
			assert.is_nil(character(function() return 7 end).guid)
		end)

		-- D10, 70170: the second return is the surname, never the realm.
		it("takes the realm from GetRealmName, not from UnitName's second return", function()
			inject("UnitName", function() return "First", "Last" end)
			inject("GetRealmName", function() return "Realm" end)

			local info = character(function() return "Player-1-00000001" end)

			assert.equals("First", info.name)
			assert.equals("Realm", info.realm)
		end)
	end)

	describe("GetServerTime", function()
		it("returns nil and a reason when the function is missing", function()
			local Api = loadApi().Api

			local now, reason = Api.GetServerTime()

			assert.is_nil(now)
			assert.equals("GetServerTime unavailable", reason)
		end)

		it("passes a number through", function()
			local Api = loadApi().Api
			inject("GetServerTime", function() return 12345 end)

			assert.equals(12345, Api.GetServerTime())
		end)
	end)

	describe("IsEventValid", function()
		it("returns nil and a reason when C_EventUtils is missing", function()
			local Api = loadApi().Api

			local valid, reason = Api.IsEventValid("PLAYER_LOGIN")

			assert.is_nil(valid)
			assert.equals("C_EventUtils.IsEventValid missing", reason)
		end)

		it("passes a boolean through, false included", function()
			local Api = loadApi().Api
			inject("C_EventUtils", { IsEventValid = function(event) return event == "PLAYER_LOGIN" end })

			assert.is_true(Api.IsEventValid("PLAYER_LOGIN"))
			assert.is_false(Api.IsEventValid("NOT_AN_EVENT"))
		end)

		it("refuses a non-boolean answer", function()
			local Api = loadApi().Api
			inject("C_EventUtils", { IsEventValid = function() return 1 end })

			local valid, reason = Api.IsEventValid("PLAYER_LOGIN")

			assert.is_nil(valid)
			assert.equals("C_EventUtils.IsEventValid returned number", reason)
		end)
	end)

	-- The stubbed ProfessionInfo below uses only field names from
	-- TradeSkillUITypesDocumentation.lua:361, with trivial values. It tests the guard, not what
	-- the client says about any real skill line -- that is S1.
	describe("GetSkillLineParents", function()
		it("fails the whole read when the function is missing", function()
			local Api = loadApi().Api

			local parents, reason = Api.GetSkillLineParents({ 1 })

			assert.is_nil(parents)
			assert.truthy(reason:find("missing", 1, true))
		end)

		it("keeps the lines that read and names the ones that threw", function()
			local Api = loadApi().Api
			inject("C_TradeSkillUI", {
				GetProfessionInfoBySkillLineID = function(id)
					if id == 2 then
						error("boom")
					end
					return { professionID = id, professionName = "child", parentProfessionID = 10,
						parentProfessionName = "parent" }
				end,
			})

			local parents, reason = Api.GetSkillLineParents({ 1, 2 })

			assert.same({ parentId = 10, parentName = "parent", name = "child", professionId = 1,
				raw = { professionID = 1, professionName = "child", parentProfessionID = 10,
					parentProfessionName = "parent" } }, parents[1])
			assert.is_nil(parents[2])
			assert.truthy(reason:find("2: error", 1, true))
		end)

		it("reads a zero or absent parent as no parent", function()
			local Api = loadApi().Api
			inject("C_TradeSkillUI", {
				GetProfessionInfoBySkillLineID = function(id)
					return { professionID = id, professionName = "top", parentProfessionID = id == 1 and 0 or nil }
				end,
			})

			local parents, reason = Api.GetSkillLineParents({ 1, 2 })

			assert.is_nil(reason)
			assert.is_nil(parents[1].parentId)
			assert.is_nil(parents[2].parentId)
		end)

		it("keeps a zeroed struct's zeros in raw, so S1 can tell it from a top-level line", function()
			local Api = loadApi().Api
			inject("C_TradeSkillUI", {
				GetProfessionInfoBySkillLineID = function()
					return { professionID = 0, professionName = "", parentProfessionID = 0 }
				end,
			})

			local parent = Api.GetSkillLineParents({ 5 })[5]

			assert.is_nil(parent.parentId)
			assert.is_nil(parent.professionId)
			assert.equals(0, parent.raw.professionID)
			assert.equals(0, parent.raw.parentProfessionID)
		end)

		-- S1, 2026-10-01: all six lines answered on a character who knows none of them, and
		-- each struct came back with all eleven documented fields (spec/fixtures/roster_geo.lua).
		it("reads the captured answers for every tradeskill line into the parent map", function()
			local captured = dofile("spec/fixtures/roster_geo.lua")
			local Api = loadApi().Api
			inject("C_TradeSkillUI", {
				GetProfessionInfoBySkillLineID = function(id)
					return captured.parentsLive[id].raw
				end,
			})

			local parents, reason = Api.GetSkillLineParents(captured.skillLines)

			-- Checked against the client's raw fields only. The derived fields beside them in
			-- the fixture are Api's own output, so comparing with those would be circular.
			assert.is_nil(reason)
			for _, id in ipairs(captured.skillLines) do
				local raw = captured.parentsLive[id].raw
				assert.same(raw, parents[id].raw)
				assert.equals(raw.parentProfessionID, parents[id].parentId)
				assert.equals(raw.parentProfessionName, parents[id].parentName)
				assert.equals(raw.professionName, parents[id].name)
				assert.equals(raw.professionID, parents[id].professionId)
			end
			assert.equals(171, parents[2937].parentId)
			assert.equals(2937, parents[2937].professionId)
		end)
	end)
	-- Forever names have a first name and a surname (Alex, 2026-10-01). The probe reads every
	-- name call side by side, and the GUID, so D10's paste says which carries the surname and
	-- whether the GUID could key the roster. Trivial values: this tests the guard, not a shape.
	describe("Probe's name rows", function()
		local function row(rows, name)
			for _, entry in ipairs(rows) do
				if entry.name == name then return entry end
			end
			error("no probe row for " .. name)
		end

		it("reads each name call, the GUID and the surname setting", function()
			local Api = loadApi().Api
			inject("UnitName", function() return "First", nil end)
			inject("UnitFullName", function() return "First", "Realm" end)
			inject("UnitNameUnmodified", function() return "First", "Last" end)
			inject("UnitGUID", function() return "Player-1-00000001" end)
			inject("C_PlayerInfo", { ShouldDisplaySurname = function() return true end })

			local rows = Api.Probe()

			-- Every return, so a surname or realm in the second slot reaches the paste.
			assert.same({ name = "UnitName", status = "ok", detail = "First, nil" },
				row(rows, "UnitName"))
			assert.equals("First, Realm", row(rows, "UnitFullName").detail)
			assert.equals("First, Last", row(rows, "UnitNameUnmodified").detail)
			assert.equals("Player-1-00000001", row(rows, "UnitGUID").detail)
			assert.equals("true", row(rows, "C_PlayerInfo.ShouldDisplaySurname").detail)
		end)

		it("reports a name call the client lacks as missing", function()
			local Api = loadApi().Api

			local rows = Api.Probe()

			assert.equals("missing", row(rows, "UnitGUID").status)
			assert.equals("missing", row(rows, "C_PlayerInfo.ShouldDisplaySurname").status)
		end)
	end)
end)
