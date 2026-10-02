local helper = require("spec.spec_helper")

-- A recorder standing in for Blizzard's Settings table. The calls and their argument order are
-- the pin's (Blizzard_Settings_Shared/Blizzard_Settings.lua:154, :178, :388, :134, :144 at
-- 9a789c0); the return values are trivial. It tests our wiring, not the panel. Whether the
-- category appears on Forever is U11.
local function stubSettings()
	local log = { settings = {}, checkboxes = {} }
	local category = { GetID = function() return 77 end }
	log.category = category
	_G.Settings = {
		VarType = { Boolean = "boolean" },
		RegisterVerticalLayoutCategory = function(name)
			log.categoryName = name
			return category, {}
		end,
		RegisterProxySetting = function(cat, variable, varType, name, default, get, set)
			local setting = { category = cat, variable = variable, varType = varType, name = name,
				default = default, get = get, set = set }
			log.settings[#log.settings + 1] = setting
			return setting
		end,
		CreateCheckbox = function(cat, setting, tooltip)
			log.checkboxes[#log.checkboxes + 1] = { category = cat, setting = setting, tooltip = tooltip }
		end,
		RegisterAddOnCategory = function(cat)
			log.registered = cat
			log.registeredAfter = #log.checkboxes
		end,
		OpenToCategory = function(id) log.opened = id end,
	}
	return log
end

local function load()
	local ns = {}
	ns.said = {}
	ns.say = function(text) ns.said[#ns.said + 1] = text end
	ns.MinimapButton = {
		hidden = false,
		locked = false,
		IsHidden = function() return ns.MinimapButton.hidden end,
		SetHidden = function(value) ns.MinimapButton.hidden = value end,
		IsLocked = function() return ns.MinimapButton.locked end,
		SetLocked = function(value) ns.MinimapButton.locked = value end,
	}
	helper.loadAddonFile("LegacyNext/UI/Options.lua", ns)
	return ns
end

local function byName(log, name)
	for _, setting in ipairs(log.settings) do
		if setting.name == name then
			return setting
		end
	end
	error("no setting named " .. name)
end

describe("Options", function()
	after_each(function()
		_G.Settings = nil
		_G.InCombatLockdown = nil
	end)

	it("registers one LegacyNext category with a checkbox per setting, then adds it last", function()
		local log = stubSettings()
		local ns = load()

		assert.is_true(ns.Options.Register())

		assert.equals("LegacyNext", log.categoryName)
		assert.equals(log.category, log.registered)
		assert.equals(#log.settings, log.registeredAfter)
		assert.equals(2, #log.checkboxes)
		for index, box in ipairs(log.checkboxes) do
			assert.equals(log.settings[index], box.setting)
			assert.equals("boolean", box.setting.varType)
			assert.is_string(box.tooltip)
		end
	end)

	it("shows the minimap button's state the right way up, and sets it", function()
		local log = stubSettings()
		local ns = load()
		ns.Options.Register()
		local show = byName(log, "Show minimap button")

		assert.is_true(show.default)
		assert.is_true(show.get())
		show.set(false)
		assert.is_true(ns.MinimapButton.hidden)
		assert.is_false(show.get())
	end)

	it("locks the minimap button", function()
		local log = stubSettings()
		local ns = load()
		ns.Options.Register()
		local lock = byName(log, "Lock minimap button")

		assert.is_false(lock.default)
		lock.set(true)
		assert.is_true(ns.MinimapButton.locked)
		assert.is_true(lock.get())
	end)

	it("uses variable names no other addon would", function()
		local log = stubSettings()
		load().Options.Register()

		for _, setting in ipairs(log.settings) do
			assert.truthy(setting.variable:find("^LEGACYNEXT_"))
		end
	end)

	it("says why when the Settings API is missing, and registers only once", function()
		local ns = load()

		local ok, reason = ns.Options.Register()
		assert.is_nil(ok)
		assert.equals("Settings.RegisterVerticalLayoutCategory missing", reason)

		local log = stubSettings()
		assert.is_true(ns.Options.Register())
		assert.is_true(ns.Options.Register())
		assert.equals(2, #log.settings)
	end)

	it("survives a registration call that throws", function()
		local log = stubSettings()
		_G.Settings.CreateCheckbox = function() error("no SettingsPanel") end
		local ns = load()

		local ok, reason = ns.Options.Register()

		assert.is_nil(ok)
		assert.truthy(reason:find("no SettingsPanel", 1, true))
		assert.is_nil(log.registered)
	end)

	-- A retry would reserve LEGACYNEXT_MINIMAP_SHOW a second time, which Blizzard refuses
	-- (Blizzard_SettingsPanel.lua:754-758), so a half-done registration is final.
	it("does not retry a registration that failed after the category existed", function()
		local log = stubSettings()
		_G.Settings.CreateCheckbox = function() error("no SettingsPanel") end
		local ns = load()
		ns.Options.Register()
		_G.Settings.CreateCheckbox = function() end

		local ok, reason = ns.Options.Register()

		assert.is_nil(ok)
		assert.truthy(reason:find("no SettingsPanel", 1, true))
		assert.equals(1, #log.settings)
	end)

	it("opens the panel on our category", function()
		local log = stubSettings()
		local ns = load()
		ns.Options.Register()

		assert.is_true(ns.Options.Open())
		assert.equals(77, log.opened)
	end)

	it("refuses to open in combat, where the panel would be blocked, and says so", function()
		local log = stubSettings()
		_G.InCombatLockdown = function() return true end
		local ns = load()
		ns.Options.Register()

		local ok, reason = ns.Options.Open()

		assert.is_nil(ok)
		assert.equals("in combat", reason)
		assert.is_nil(log.opened)
		assert.equals(1, #ns.said)
	end)

	it("says why it cannot open before registering", function()
		local ns = load()

		local ok, reason = ns.Options.Open()

		assert.is_nil(ok)
		assert.equals("settings not registered: Settings.RegisterVerticalLayoutCategory missing", reason)
		assert.equals(1, #ns.said)
	end)

	it("describes itself for /lgn uidump", function()
		local ns = load()
		ns.Options.Register()
		assert.same({ registered = false, reason = "Settings.RegisterVerticalLayoutCategory missing" },
			ns.Options.Describe())

		stubSettings()
		ns.Options.Register()
		assert.same({ registered = true }, ns.Options.Describe())
	end)
end)
