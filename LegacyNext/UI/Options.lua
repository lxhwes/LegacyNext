local _, ns = ...

-- Esc > Options > AddOns > LegacyNext. A vertical-layout category of proxy settings, so every
-- value goes through MinimapButton and Store, and Store stays the only file that names
-- LegacyNextDB. The other kind, RegisterAddOnSetting, would hand Blizzard the SavedVariables
-- table itself (Blizzard_Setting.lua:417-427 at 9a789c0).
--
-- Every call is the pin's, in its order (Blizzard_Settings_Shared/Blizzard_Settings.lua):
--   RegisterVerticalLayoutCategory(name) -> category, layout          :154
--   RegisterProxySetting(category, variable, varType, name, default, get, set)   :178
--   CreateCheckbox(category, setting, tooltip)                         :388
--   RegisterAddOnCategory(category), called last, as the readme does   :134, Readme :97
--   OpenToCategory(category:GetID())                                   :144, Blizzard_Category.lua:13
-- The shared settings addon loads on camelot (Blizzard_Settings_Shared.toc:7). Seen in game is U11.
ns.Options = ns.Options or {}
local Options = ns.Options

local CATEGORY_NAME = "LegacyNext"

Options.category = nil
Options.reason = nil
-- Set once the category exists, so a registration that fails part-way is final. A retry would
-- reserve the same setting variables again, which Blizzard refuses with "previously
-- registered" (Blizzard_SettingsPanel.lua:754-758 at 9a789c0), hiding the first error.
local started = false

local function G(name)
	return rawget(_G, name)
end

local function inCombat()
	local check = G("InCombatLockdown")
	return type(check) == "function" and check() and true or false
end

local function say(text)
	if type(ns.say) == "function" then
		ns.say(text)
	end
end

local CHECKBOXES = {
	{
		key = "minimapHidden",
		variable = "LEGACYNEXT_MINIMAP_SHOW",
		name = "Show minimap button",
		tooltip = "The LegacyNext button on the minimap's edge. The minimap's addon dropdown lists LegacyNext either way.",
		default = true,
		get = function() return not ns.MinimapButton.IsHidden() end,
		set = function(value) return ns.MinimapButton.SetHidden(not value) end,
	},
	{
		key = "minimapLocked",
		variable = "LEGACYNEXT_MINIMAP_LOCK",
		name = "Lock minimap button",
		tooltip = "Stop the minimap button moving when dragged.",
		default = false,
		get = function() return ns.MinimapButton.IsLocked() end,
		set = function(value) return ns.MinimapButton.SetLocked(value) end,
	},
}

-- External writes need a notification (Blizzard_Settings_Shared/Blizzard_Settings.lua:206-210,
-- Blizzard_Setting.lua:180-188 at 9a789c0); a proxy getter alone does not refresh a checkbox.
function Options.NotifyChanged(key)
	local settings = G("Settings")
	if not Options.category or type(settings) ~= "table" or type(settings.NotifyUpdate) ~= "function" then
		return
	end
	for _, box in ipairs(CHECKBOXES) do
		if box.key == key then
			pcall(settings.NotifyUpdate, box.variable)
			return
		end
	end
end

local function setCheckbox(box, value)
	local ok, reason = box.set(value)
	if not ok then
		say("could not change " .. box.name .. ": " .. tostring(reason))
		-- ApplyValue publishes the requested value after the setter (:136), ignoring its result
		-- (ProxySettingMixin :333-335). Refresh after that event to show the stored value instead.
		-- C_Timer.After(seconds, callback): UITimerDocumentation.lua:11-19, used with 0 in
		-- Blizzard_SharedXMLGame/DressUpModelFrameMixin.lua:188 at 9a789c0.
		local timer = G("C_Timer")
		if type(timer) == "table" and type(timer.After) == "function" then
			pcall(timer.After, 0, function() Options.NotifyChanged(box.key) end)
		end
	end
	return ok, reason
end

local function register(settings)
	local category = settings.RegisterVerticalLayoutCategory(CATEGORY_NAME)
	if type(category) ~= "table" then
		error("RegisterVerticalLayoutCategory returned " .. type(category))
	end
	started = true
	local boolean = type(settings.VarType) == "table" and settings.VarType.Boolean or "boolean"
	for _, box in ipairs(CHECKBOXES) do
		local setting = settings.RegisterProxySetting(category, box.variable, boolean, box.name, box.default,
			box.get, function(value) return setCheckbox(box, value) end)
		settings.CreateCheckbox(category, setting, box.tooltip)
	end
	settings.RegisterAddOnCategory(category)
	return category
end

-- Registers the category once. True, or nil plus a reason.
function Options.Register()
	if Options.category then
		return true
	end
	if started then
		return nil, Options.reason
	end
	local settings = G("Settings")
	if type(settings) ~= "table" then
		Options.reason = "Settings.RegisterVerticalLayoutCategory missing"
		return nil, Options.reason
	end
	for _, name in ipairs({ "RegisterVerticalLayoutCategory", "RegisterProxySetting", "CreateCheckbox",
		"RegisterAddOnCategory" }) do
		if type(settings[name]) ~= "function" then
			Options.reason = "Settings." .. name .. " missing"
			return nil, Options.reason
		end
	end
	local ok, result = pcall(register, settings)
	if not ok then
		Options.reason = "registration failed: " .. tostring(result)
		return nil, Options.reason
	end
	Options.category, Options.reason = result, nil
	return true
end

-- Opens the panel on our category. Refused in combat, where ShowUIPanel blocks addon calls
-- (UIParentPanelManager.lua:853-858). A refusal is said in chat.
function Options.Open()
	local reason
	-- A login that could not register yet gets another try here.
	local registered, why = true, nil
	if not Options.category then
		registered, why = Options.Register()
	end
	if inCombat() then
		reason = "in combat"
	elseif not registered then
		reason = "settings not registered: " .. tostring(why)
	else
		local settings = G("Settings")
		local category = Options.category
		if type(settings) ~= "table" or type(settings.OpenToCategory) ~= "function" then
			reason = "Settings.OpenToCategory missing"
		elseif type(category.GetID) ~= "function" then
			reason = "category has no GetID"
		else
			local ok, err = pcall(function() settings.OpenToCategory(category:GetID()) end)
			if ok then
				return true
			end
			reason = "Settings.OpenToCategory error: " .. tostring(err)
		end
	end
	say("could not open settings: " .. reason)
	return nil, reason
end

function Options.Describe()
	if Options.category then
		return { registered = true }
	end
	return { registered = false, reason = Options.reason }
end
