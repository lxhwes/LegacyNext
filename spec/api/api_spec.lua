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

		it("refuses a cyclic table", function()
			local Api = loadApi().Api
			local source = {}
			source.self = source

			local copy, reason = Api.PlainCopy(source)

			assert.is_nil(copy)
			assert.equals("cyclic", reason)
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
end)
