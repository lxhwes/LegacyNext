local helper = require("spec.spec_helper")

local function loadDebug()
	local ns = helper.loadAddonFile("LegacyNext/Api/Api.lua")
	helper.loadAddonFile("LegacyNext/Debug/Debug.lua", ns)
	return ns.Debug
end

local function roundTrip(value)
	local Debug = loadDebug()
	local literal = Debug.Serialize(value)
	local chunk = assert(loadstring("return " .. literal))
	return chunk(), literal
end

describe("Debug.Serialize", function()
	it("loads without touching WoW globals", function()
		assert.is_table(loadDebug())
	end)

	it("round-trips a nested table", function()
		local source = {
			id = 62012,
			name = "Journeyman Alchemist",
			completed = false,
			criteria = {
				{ text = "150 Alchemy Skill", have = 0, need = 150, criteriaType = 7, assetId = 2937 },
			},
		}

		assert.same(source, (roundTrip(source)))
	end)

	it("escapes the pipe the EditBox would read as a colour code", function()
		local decoded, literal = roundTrip({ text = "|cffff0000red|r" })

		assert.equals("|cffff0000red|r", decoded.text)
		assert.is_nil(literal:find("|", 1, true))
	end)

	it("escapes a newline rather than breaking the line", function()
		local decoded, literal = roundTrip({ text = "first\nsecond" })

		assert.equals("first\nsecond", decoded.text)
		assert.is_truthy(literal:find([["first\nsecond"]], 1, true))
	end)

	it("quotes keys that are not identifiers", function()
		local decoded = roundTrip({ ["not an identifier"] = 1, [3] = "three", ["end"] = true })

		assert.equals(1, decoded["not an identifier"])
		assert.equals("three", decoded[3])
		assert.is_true(decoded["end"])
	end)

	it("is stable across repeated runs", function()
		local source = { b = 1, a = 2, [2] = "two", [1] = "one" }

		assert.equals(select(2, roundTrip(source)), select(2, roundTrip(source)))
	end)

	it("writes an empty table inline", function()
		local decoded, literal = roundTrip({ criteria = {} })

		assert.same({}, decoded.criteria)
		assert.is_truthy(literal:find("criteria = {}", 1, true))
	end)
end)
