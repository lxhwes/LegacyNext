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
	local handler, savedPrint, ns
	-- Events a test wants the stubbed RegisterEvent to throw on, as the client does for a name
	-- it does not know.
	local unknownEvents, registered

	local function boot()
		registered = {}
		ns = {}
		for _, path in ipairs(tocFiles()) do
			helper.loadAddonFile(path, ns)
		end
	end

	before_each(function()
		savedPrint = _G.print
		_G.print = function() end
		for name, value in pairs(STUBS) do
			_G[name] = value
		end
		unknownEvents = {}
		_G.CreateFrame = function()
			return setmetatable({}, { __index = function(self, key)
				if key == "SetScript" then
					return function(_, _, fn) handler = fn end
				end
				if key == "RegisterEvent" then
					return function(_, event)
						if unknownEvents[event] then
							error('Attempt to register unknown event "' .. event .. '"')
						end
						registered[event] = true
					end
				end
				return function() return self end
			end })
		end
		_G.UIParent = _G.CreateFrame()
		_G.UISpecialFrames = {}

		boot()
	end)

	after_each(function()
		_G.print = savedPrint
		for name in pairs(STUBS) do
			_G[name] = nil
		end
		for _, name in ipairs({ "CreateFrame", "UIParent", "UISpecialFrames", "LegacyNextDB",
			"SLASH_LEGACYNEXT1", "SLASH_LEGACYNEXT2", "C_EventUtils", "C_Timer" }) do
			_G[name] = nil
		end
	end)

	describe("snapshot events", function()
		local timers

		local function runTimers()
			local due = timers
			timers = {}
			for _, timer in ipairs(due) do
				timer.fn()
			end
		end

		local function stored()
			return _G.LegacyNextDB.characters["Tester-Realm"]
		end

		before_each(function()
			timers = {}
			_G.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
			handler(nil, "ADDON_LOADED", "LegacyNext")
		end)

		it("snapshots a level-up after the delay, not at once", function()
			handler(nil, "PLAYER_LEVEL_UP")
			assert.is_nil(stored())
			assert.equals(5, timers[1].delay)

			runTimers()

			assert.equals(10, stored().level)
			assert.equals("PLAYER_LEVEL_UP -> written", ns.lastSnapshot)
		end)

		it("restarts the wait on each event and snapshots once, after the last", function()
			handler(nil, "SKILL_LINES_CHANGED")
			local first = timers[1]
			_G.UnitLevel = function() return 12 end
			handler(nil, "PLAYER_LEVEL_UP")
			handler(nil, "PLAYER_LEVEL_UP")

			first.fn()
			assert.is_nil(stored())

			runTimers()
			assert.equals(12, stored().level)
			assert.equals("SKILL_LINES_CHANGED+PLAYER_LEVEL_UP -> written", ns.lastSnapshot)
		end)

		it("delays the login snapshot the same way", function()
			handler(nil, "PLAYER_LOGIN")
			assert.is_nil(stored())

			runTimers()
			assert.is_table(stored())
		end)

		it("snapshots at once when C_Timer is missing", function()
			_G.C_Timer = nil

			handler(nil, "TRAIT_CONFIG_UPDATED")

			assert.equals(10, stored().level)
		end)
	end)

	describe("event registration", function()
		it("registers the lifecycle and snapshot events", function()
			for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_LEVEL_UP",
				"SKILL_LINES_CHANGED", "TRAIT_CONFIG_UPDATED" }) do
				assert.is_true(registered[event], event)
			end
			assert.same({}, ns.eventsNotRegistered)
		end)

		it("still sets up the slash commands when registering an event throws", function()
			unknownEvents.TRAIT_CONFIG_UPDATED = true
			_G.SlashCmdList = {}

			boot()

			assert.is_function(_G.SlashCmdList.LEGACYNEXT)
			assert.is_function(handler)
			assert.is_true(registered.PLAYER_LOGOUT)
			assert.equals(1, #ns.eventsNotRegistered)
			assert.truthy(ns.eventsNotRegistered[1]:find("TRAIT_CONFIG_UPDATED (", 1, true))
			assert.truthy(ns.ReadRosterInput().eventsNotRegistered[1]:find("unknown event", 1, true))
		end)

		it("skips an event the client reports invalid without trying it", function()
			_G.C_EventUtils = { IsEventValid = function(event) return event ~= "SKILL_LINES_CHANGED" end }

			boot()

			assert.is_nil(registered.SKILL_LINES_CHANGED)
			assert.is_true(registered.PLAYER_LEVEL_UP)
			assert.same({ "SKILL_LINES_CHANGED (unknown to this client)" }, ns.eventsNotRegistered)
		end)
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
