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
			"SLASH_LEGACYNEXT1", "SLASH_LEGACYNEXT2", "C_EventUtils", "C_Timer", "C_AddOns",
			"LegacyNext_OnAddonCompartmentClick", "LegacyNext_OnAddonCompartmentEnter",
			"LegacyNext_OnAddonCompartmentLeave", "UnitGUID" }) do
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
			-- No C_Traits stub, so the result names the part it could not read.
			assert.equals("PLAYER_LEVEL_UP -> written; trees: unspent points not read", ns.lastSnapshot)
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
			assert.truthy(ns.lastSnapshot:find("SKILL_LINES_CHANGED+PLAYER_LEVEL_UP -> written", 1, true))
		end)

		-- The window refreshes on its own two events only. A level-up, skill-up or spent point
		-- changes the Roster tab, and the delayed snapshot is what knows when.
		it("asks the window to redraw after a delayed snapshot", function()
			local asked = 0
			ns.UI.OnSnapshot = function() asked = asked + 1 end

			handler(nil, "PLAYER_LEVEL_UP")
			assert.equals(0, asked)
			runTimers()

			assert.equals(1, asked)
			handler(nil, "PLAYER_LOGOUT")
			assert.equals(1, asked)
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

		-- S1 logged 51 skill-ups in 45 minutes. The session log stays as short as Store's,
		-- keeping the login result first and counting the middle it drops.
		it("keeps the first snapshot this session and the latest, up to Store's limit", function()
			_G.C_Timer = nil
			for _ = 1, ns.Store.LOG_LIMIT + 5 do
				handler(nil, "SKILL_LINES_CHANGED")
			end

			local input = ns.ReadRosterInput()

			assert.equals(ns.Store.LOG_LIMIT, #input.snapshotLog)
			assert.equals(5, input.snapshotLogSkipped)
			assert.equals(ns.Store.LOG_LIMIT, #_G.LegacyNextDB.snapshotLog)
		end)

		it("shows the last session's logout result, and keeps /lgn roster out of the log", function()
			handler(nil, "PLAYER_LOGOUT")
			assert.equals(1, #_G.LegacyNextDB.snapshotLog)

			boot() -- a /reload: same global, fresh addon
			handler(nil, "ADDON_LOADED", "LegacyNext")
			local input = ns.ReadRosterInput()

			local earlier = input.diagnostics.loadedLog
			assert.equals(1, #earlier)
			assert.equals(1, earlier[1].session)
			assert.truthy(earlier[1].text:find("PLAYER_LOGOUT -> written", 1, true))
			assert.same({}, input.snapshotLog)
			assert.truthy(input.snapshotResult:find("roster command -> written", 1, true))
			assert.equals(1, #_G.LegacyNextDB.snapshotLog)
		end)
	end)

	it("carries a failed challenge read into the roster input", function()
		-- No GetCategoryList stub: the category read fails before any challenge is read.
		handler(nil, "ADDON_LOADED", "LegacyNext")

		local input = ns.ReadRosterInput()

		assert.is_nil(input.challenges)
		assert.equals("categories: GetCategoryList unavailable", input.challengesReason)
		assert.same({}, input.candidates)
	end)

	it("gives the window the roster and the current character, outside the snapshot log", function()
		handler(nil, "ADDON_LOADED", "LegacyNext")

		local input = ns.ReadViewInput()

		assert.equals("Tester-Realm", input.currentKey)
		assert.equals("Tester-Realm", input.snapshots[1].key)
		assert.same({}, input.candidates)
		assert.equals(5000, input.now)
		assert.equals(0, #(_G.LegacyNextDB.snapshotLog or {}))
	end)

	-- Every window refresh runs this, CRITERIA_UPDATE's included: the character read is up to
	-- twelve client calls, and the snapshot has already made it.
	it("reads the character once per window read", function()
		local reads = 0
		_G.UnitClass = function() reads = reads + 1 return "Druid", "DRUID", 11 end
		handler(nil, "ADDON_LOADED", "LegacyNext")

		local input = ns.ReadViewInput()

		assert.equals(1, reads)
		assert.equals("Druid", input.character.class)
	end)

	it("leaves the saved skill-line map alone when this session's lookup gave nothing", function()
		_G.LegacyNextDB = { schema = 1, skillLineParents = { [2937] = { parentId = 171 } } }
		handler(nil, "ADDON_LOADED", "LegacyNext")
		local saved = _G.LegacyNextDB.skillLineParents

		ns.ReadViewInput()
		ns.ReadRosterInput()

		assert.equals(saved, _G.LegacyNextDB.skillLineParents)
		assert.is_nil(saved[2937].saved)
	end)

	it("tells the window why this character's snapshot was not written", function()
		_G.LegacyNextDB = { schema = 2 }
		handler(nil, "ADDON_LOADED", "LegacyNext")

		local input = ns.ReadViewInput()

		assert.equals("saved schema 2, this build reads 1", input.snapshotProblem)
		assert.truthy(ns.Debug.BuildUIDump("roster"):find("This character was not saved: saved schema 2", 1, true))
	end)

	it("gives the window no snapshot problem once the write lands", function()
		handler(nil, "ADDON_LOADED", "LegacyNext")

		assert.is_nil(ns.ReadViewInput().snapshotProblem)
	end)

	it("runs /lgn uidump on both tabs without a failure message", function()
		local printed = {}
		_G.print = function(message) printed[#printed + 1] = tostring(message) end
		handler(nil, "ADDON_LOADED", "LegacyNext")

		_G.SlashCmdList.LEGACYNEXT("uidump")
		_G.SlashCmdList.LEGACYNEXT("uidump roster")

		for _, line in ipairs(printed) do
			assert.is_nil(line:find("failed", 1, true), line)
		end
		-- No GetCategoryList stub: Next Up is in its error state, and the roster is not.
		assert.truthy(ns.Debug.BuildUIDump(nil):find("state=error  Could not read your challenges", 1, true))
		local roster = ns.Debug.BuildUIDump("roster")
		assert.truthy(roster:find("tab=roster", 1, true))
		assert.truthy(roster:find("Tester  L10 Druid", 1, true))
		assert.truthy(roster:find("state=ok", 1, true))
	end)

	it("uses and keeps the saved skill-line map when this session's lookup is missing", function()
		_G.LegacyNextDB = { schema = 1, skillLineParents = { [2937] = { parentId = 171 } } }
		handler(nil, "ADDON_LOADED", "LegacyNext")

		local input = ns.ReadRosterInput()

		assert.is_nil(input.parentsLive)
		assert.equals(171, input.parents[2937].parentId)
		assert.is_true(input.parents[2937].saved)
		assert.equals(171, _G.LegacyNextDB.skillLineParents[2937].parentId)
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

	describe("version", function()
		local function versionAtLogin(metadata)
			_G.C_AddOns = { GetAddOnMetadata = function(_, key)
				if key == "Version" then return metadata end
			end }
			handler(nil, "PLAYER_LOGIN")
			return ns.version
		end

		-- A dev build is LegacyNext/ copied from the repo, so the packager never replaced the token.
		it("reports dev when ## Version is the unreplaced packager token", function()
			assert.equals("dev", versionAtLogin("@project-version@"))
		end)

		it("reports the tag the packager wrote", function()
			assert.equals("v0.1.0", versionAtLogin("v0.1.0"))
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

	describe("addon compartment", function()
		-- The compartment calls _G[name] for the name the TOC gives (AddonCompartment.lua:81, :99).
		local function compartmentFunc()
			for line in io.lines("LegacyNext/LegacyNext.toc") do
				local name = line:match("^## AddonCompartmentFunc:%s*(%S+)")
				if name then
					return name
				end
			end
		end

		it("names a global function in the TOC that Core defines", function()
			local name = compartmentFunc()

			assert.is_string(name)
			assert.is_function(_G[name])
		end)

		-- The hover globals get (addonName, button) (AddonCompartment.lua:106-117).
		it("names hover globals in the TOC that show and hide the summary tooltip", function()
			local names = {}
			for line in io.lines("LegacyNext/LegacyNext.toc") do
				local key, name = line:match("^## (AddonCompartmentFuncOn%a+):%s*(%S+)")
				if key then
					names[key] = name
				end
			end
			local shown, hidden = {}, 0
			ns.MinimapButton.ShowTooltip = function(owner, hint) shown[#shown + 1] = { owner, hint } end
			ns.MinimapButton.HideTooltip = function() hidden = hidden + 1 end
			local entry = {}

			_G[names.AddonCompartmentFuncOnEnter]("LegacyNext", entry)
			_G[names.AddonCompartmentFuncOnLeave]("LegacyNext", entry)

			assert.equals(1, #shown)
			assert.equals(entry, shown[1][1])
			assert.equals(ns.MinimapButton.COMPARTMENT_HINT, shown[1][2])
			assert.equals(1, hidden)
		end)

		it("toggles the window on any click", function()
			local toggles = 0
			ns.UI.Toggle = function() toggles = toggles + 1 end

			_G[compartmentFunc()]("LegacyNext", "LeftButton")
			_G[compartmentFunc()]("LegacyNext", "RightButton")

			assert.equals(2, toggles)
		end)
	end)

	-- The AddOns list reads it as metadata "Category" and groups on the exact string
	-- (AddonList.lua:456, :486-490).
	it("names a Category in the TOC for the AddOns list", function()
		local category
		for line in io.lines("LegacyNext/LegacyNext.toc") do
			category = category or line:match("^## Category:%s*(.-)%s*$")
		end

		assert.equals("Achievements", category)
	end)

	describe("key binding", function()
		-- Each <Binding> in Bindings.xml: its name, its category and the Lua the client runs.
		local function bindings()
			local file = assert(io.open("LegacyNext/Bindings.xml"))
			local xml = file:read("*a")
			file:close()
			local found = {}
			for attributes, body in xml:gmatch("<Binding%s+([^>]-)>(.-)</Binding>") do
				found[#found + 1] = {
					name = attributes:match('name="([^"]*)"'),
					category = attributes:match('category="([^"]*)"'),
					body = body,
				}
			end
			return found
		end

		after_each(function()
			_G.LegacyNext_Toggle = nil
			for name in pairs(_G) do
				if type(name) == "string" and name:find("^BINDING_NAME_") then
					_G[name] = nil
				end
			end
		end)

		-- The settings list labels a row with BINDING_NAME_<name> and falls back to the bare
		-- name (BindingUtil.lua:142-149).
		it("puts one binding under AddOns with a label Core defines", function()
			local list = bindings()

			assert.equals(1, #list)
			assert.equals("ADDONS", list[1].category)
			assert.is_string(_G["BINDING_NAME_" .. list[1].name])
		end)

		it("opens and closes the window from the binding's own Lua", function()
			-- The plain stub's IsShown is always truthy, so track Show and Hide per frame.
			local plain = _G.CreateFrame
			_G.CreateFrame = function(...)
				local frame = plain(...)
				local shown = true
				rawset(frame, "Show", function() shown = true end)
				rawset(frame, "Hide", function() shown = false end)
				rawset(frame, "IsShown", function() return shown end)
				return frame
			end
			local press = assert(loadstring(bindings()[1].body))

			press()
			assert.is_true(ns.UI.frame:IsShown())

			press()
			assert.is_false(ns.UI.frame:IsShown())
		end)
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

	-- Trivial GUID stub: these test the Store calls around the move, not UnitGUID's shape.
	describe("GUID keys", function()
		local GUID = "Player-1-00000001"

		before_each(function()
			_G.UnitGUID = function() return GUID end
		end)

		it("moves this character's Name-Realm row to its GUID at login, and leaves alts alone", function()
			_G.LegacyNextDB = { schema = 1, sessions = 1, characters = {
				["Tester-Realm"] = { key = "Tester-Realm", name = "Tester", realm = "Realm", level = 9,
					professions = { { name = "Alchemy", skillLineId = 171, skill = 50 } }, professionsAt = 1 },
				["Alt-Realm"] = { key = "Alt-Realm", name = "Alt", realm = "Realm" },
			} }

			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")

			local characters = _G.LegacyNextDB.characters
			assert.is_nil(characters["Tester-Realm"])
			assert.equals(GUID, characters[GUID].key)
			assert.equals(10, characters[GUID].level)
			-- GetProfessions read nothing, so the moved row's list is kept.
			assert.equals("Alchemy", characters[GUID].professions[1].name)
			assert.is_table(characters["Alt-Realm"])
			assert.equals(GUID, ns.currentKey)
			assert.truthy(ns.lastSnapshot:find("migrated from Tester-Realm", 1, true), ns.lastSnapshot)
		end)

		it("writes under the GUID after the move, without moving anything again", function()
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")
			handler(nil, "PLAYER_LOGOUT")

			assert.equals(GUID, _G.LegacyNextDB.characters[GUID].key)
			assert.is_nil(_G.LegacyNextDB.characters["Tester-Realm"])
			assert.is_nil(ns.lastSnapshot:find("migrated", 1, true), ns.lastSnapshot)
		end)

		it("forgets a GUID-keyed character by Name-Realm", function()
			local printed = {}
			_G.print = function(message) printed[#printed + 1] = tostring(message) end
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")
			assert.is_table(_G.LegacyNextDB.characters[GUID])

			_G.SlashCmdList.LEGACYNEXT("roster forget Tester-Realm")

			assert.truthy(printed[#printed]:find("forgot Tester-Realm", 1, true), printed[#printed])
			assert.is_nil(_G.LegacyNextDB.characters[GUID])
		end)

		it("says why a forget matched nothing", function()
			local printed = {}
			_G.print = function(message) printed[#printed + 1] = tostring(message) end
			handler(nil, "ADDON_LOADED", "LegacyNext")

			_G.SlashCmdList.LEGACYNEXT("roster forget Nobody-Realm")

			assert.truthy(printed[#printed]:find("not forgotten: no character Nobody-Realm", 1, true),
				printed[#printed])
		end)
	end)

	it("keeps an earlier session's characters", function()
		_G.LegacyNextDB = { schema = 1, sessions = 1, characters = { ["Alt-Realm"] = { key = "Alt-Realm" } } }

		handler(nil, "ADDON_LOADED", "LegacyNext")
		handler(nil, "PLAYER_LOGIN")

		assert.equals(2, _G.LegacyNextDB.sessions)
		assert.is_table(_G.LegacyNextDB.characters["Alt-Realm"])
		assert.is_table(_G.LegacyNextDB.characters["Tester-Realm"])
	end)

	describe("challenge clicks", function()
		local said

		before_each(function()
			said = {}
			_G.print = function(text) said[#said + 1] = text end
		end)

		local function stubActions(linkClick)
			local done = {}
			ns.Api.IsLinkClick = function() return linkClick end
			ns.Api.LinkChallenge = function(id) done[#done + 1] = "link " .. id return true end
			ns.Api.OpenLegacyChallenge = function(id) done[#done + 1] = "open " .. id return true end
			return done
		end

		it("opens Blizzard's panel on a plain click", function()
			local done = stubActions(false)

			ns.UI.actions.challengeClick(61499)

			assert.same({ "open 61499" }, done)
			assert.same({}, said)
		end)

		it("links the challenge on a chat-link click", function()
			local done = stubActions(true)

			ns.UI.actions.challengeClick(61499)

			assert.same({ "link 61499" }, done)
		end)

		it("says why the panel did not open", function()
			stubActions(false)
			ns.Api.OpenLegacyChallenge = function() return nil, "in combat" end

			ns.UI.actions.challengeClick(61499)

			assert.equals(1, #said)
			assert.truthy(said[1]:find("could not open the Legacy panel: in combat", 1, true))
		end)

		it("says why the link did not land", function()
			stubActions(true)
			ns.Api.LinkChallenge = function() return nil, "open a chat box first" end

			ns.UI.actions.challengeClick(61499)

			assert.truthy(said[1]:find("could not link it: open a chat box first", 1, true))
		end)
	end)

	describe("minimap button and settings", function()
		after_each(function()
			_G.Minimap = nil
			_G.Settings = nil
		end)

		local function stubSettings()
			local log = {}
			_G.Settings = {
				RegisterVerticalLayoutCategory = function() return { GetID = function() return 9 end } end,
				RegisterProxySetting = function(_, variable) return { variable = variable } end,
				CreateCheckbox = function() end,
				RegisterAddOnCategory = function() log.registered = true end,
				OpenToCategory = function(id) log.opened = id end,
			}
			return log
		end

		it("builds the button and registers the settings at login", function()
			_G.Minimap = _G.CreateFrame()
			local log = stubSettings()
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")

			assert.is_true(ns.MinimapButton.Describe().created)
			assert.is_true(log.registered)
			assert.is_nil(ns.minimapReason)
			assert.is_nil(ns.optionsReason)
		end)

		it("keeps the reasons when neither can come up, and still logs in", function()
			handler(nil, "ADDON_LOADED", "LegacyNext")
			assert.has_no.errors(function() handler(nil, "PLAYER_LOGIN") end)

			assert.equals("no Minimap frame", ns.minimapReason)
			assert.equals("Settings.RegisterVerticalLayoutCategory missing", ns.optionsReason)
			assert.is_table(_G.LegacyNextDB.characters["Tester-Realm"])
		end)

		it("toggles the button from /lgn minimap and saves it account-wide", function()
			_G.Minimap = _G.CreateFrame()
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")

			_G.SlashCmdList.LEGACYNEXT("minimap")
			assert.is_true(_G.LegacyNextDB.settings.minimapHidden)
			_G.SlashCmdList.LEGACYNEXT("minimap")
			assert.is_false(_G.LegacyNextDB.settings.minimapHidden)
		end)

		it("notifies an already displayed settings checkbox after /lgn minimap", function()
			local log = stubSettings()
			_G.Settings.NotifyUpdate = function(variable)
				log.variable = variable
				log.checked = not ns.MinimapButton.IsHidden()
			end
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")

			_G.SlashCmdList.LEGACYNEXT("minimap")
			assert.equals("LEGACYNEXT_MINIMAP_SHOW", log.variable)
			assert.is_false(log.checked)
			_G.SlashCmdList.LEGACYNEXT("minimap")
			assert.is_true(log.checked)
		end)

		it("reports a refused slash-command setting write instead of success", function()
			_G.LegacyNextDB = { schema = 2, settings = { minimapHidden = false } }
			handler(nil, "ADDON_LOADED", "LegacyNext")
			local said = {}
			_G.print = function(text) said[#said + 1] = text end

			_G.SlashCmdList.LEGACYNEXT("minimap")

			assert.is_false(_G.LegacyNextDB.settings.minimapHidden)
			assert.equals(1, #said)
			assert.truthy(said[1]:find("could not change minimap button: saved schema 2", 1, true))
		end)

		it("opens the settings from /lgn config", function()
			local log = stubSettings()
			handler(nil, "ADDON_LOADED", "LegacyNext")
			handler(nil, "PLAYER_LOGIN")

			_G.SlashCmdList.LEGACYNEXT("config")

			assert.equals(9, log.opened)
		end)
	end)
end)
