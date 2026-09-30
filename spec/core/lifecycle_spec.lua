local helper = require("spec.spec_helper")

-- Loads every file the TOC lists, in the TOC's order, then plays the client's event sequence
-- at it. The globals below are trivial stubs that test wiring -- ADDON_LOADED attaching the
-- store, PLAYER_LOGIN and PLAYER_LOGOUT writing a snapshot -- not any response shape.
-- Reading the TOC is deliberate: a source file missing from it never loads in game, silently.
local function tocFiles()
	local files = {}
	for line in io.lines("LegacyNext/LegacyNext.toc") do
		line = line:gsub("\r$", "")
		if line ~= "" and not line:find("^#") then
			files[#files + 1] = "LegacyNext/" .. line:gsub("\\", "/")
		end
	end
	return files
end

local STUBS = {
	UnitName = function() return "Tester" end,
	GetRealmName = function() return "Realm" end,
	UnitClass = function() return "Druid", "DRUID", 11 end,
	UnitLevel = function() return 10 end,
	GetProfessions = function() end,
	GetServerTime = function() return 5000 end,
	SlashCmdList = {},
}

describe("addon lifecycle", function()
	local handler, savedPrint

	before_each(function()
		savedPrint = _G.print
		_G.print = function() end
		for name, value in pairs(STUBS) do
			_G[name] = value
		end
		_G.CreateFrame = function()
			return setmetatable({}, { __index = function(self, key)
				if key == "SetScript" then
					return function(_, _, fn) handler = fn end
				end
				return function() return self end
			end })
		end
		_G.UIParent = _G.CreateFrame()
		_G.UISpecialFrames = {}

		local ns = {}
		for _, path in ipairs(tocFiles()) do
			helper.loadAddonFile(path, ns)
		end
	end)

	after_each(function()
		_G.print = savedPrint
		for name in pairs(STUBS) do
			_G[name] = nil
		end
		for _, name in ipairs({ "CreateFrame", "UIParent", "UISpecialFrames", "LegacyNextDB",
			"SLASH_LEGACYNEXT1", "SLASH_LEGACYNEXT2" }) do
			_G[name] = nil
		end
	end)

	it("lists Model/Roster.lua in the TOC before Core.lua, which stays last", function()
		local files = tocFiles()

		assert.equals("LegacyNext/Core.lua", files[#files])
		local found = false
		for _, path in ipairs(files) do
			found = found or path == "LegacyNext/Model/Roster.lua"
		end
		assert.is_true(found)
	end)

	it("attaches the store on its own ADDON_LOADED and snapshots at login and logout", function()
		handler(nil, "ADDON_LOADED", "SomeOtherAddon")
		assert.is_nil(_G.LegacyNextDB)

		handler(nil, "ADDON_LOADED", "LegacyNext")
		assert.equals(1, _G.LegacyNextDB.sessions)

		handler(nil, "PLAYER_LOGIN")
		local snapshot = _G.LegacyNextDB.characters["Tester-Realm"]
		assert.equals(10, snapshot.level)
		assert.equals(5000, snapshot.takenAt)
		assert.same({}, snapshot.professions)

		_G.UnitLevel = function() return 11 end
		handler(nil, "PLAYER_LOGOUT")
		assert.equals(11, _G.LegacyNextDB.characters["Tester-Realm"].level)
	end)

	it("runs /lgn roster end to end without a failure message", function()
		local printed = {}
		_G.print = function(message) printed[#printed + 1] = tostring(message) end
		handler(nil, "ADDON_LOADED", "LegacyNext")
		handler(nil, "PLAYER_LOGIN")

		_G.SlashCmdList.LEGACYNEXT("roster")
		_G.SlashCmdList.LEGACYNEXT("roster forget Tester-Realm")

		for _, line in ipairs(printed) do
			assert.is_nil(line:find("failed", 1, true), line)
		end
		assert.truthy(printed[#printed]:find("forgot Tester-Realm", 1, true))
		assert.is_nil(_G.LegacyNextDB.characters["Tester-Realm"])
	end)

	it("keeps an earlier session's characters", function()
		_G.LegacyNextDB = { schema = 1, sessions = 1, characters = { ["Alt-Realm"] = { key = "Alt-Realm" } } }

		handler(nil, "ADDON_LOADED", "LegacyNext")
		handler(nil, "PLAYER_LOGIN")

		assert.equals(2, _G.LegacyNextDB.sessions)
		assert.is_table(_G.LegacyNextDB.characters["Alt-Realm"])
		assert.is_table(_G.LegacyNextDB.characters["Tester-Realm"])
	end)
end)
