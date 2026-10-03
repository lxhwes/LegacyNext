local helper = require("spec.spec_helper")

-- A small widget double for the minimap button: it keeps anchors, scripts, textures and shown
-- state so the button's wiring can be checked. It asserts nothing about the client's frame
-- API; any method name is accepted. Whether the button draws and drags is U10.
local function newWidget(kind, name, parent)
	local widget = { kind = kind, name = name, parent = parent, shown = true, textures = {} }
	return setmetatable(widget, {
		__index = function(self, key)
			if key == "SetScript" then
				return function(_, event, fn) self["script_" .. event] = fn end
			elseif key == "GetScript" then
				return function(_, event) return rawget(self, "script_" .. event) end
			elseif key == "SetPoint" then
				return function(_, ...) self.point = { ... } end
			elseif key == "Show" then
				return function() self.shown = true end
			elseif key == "Hide" then
				return function() self.shown = false end
			elseif key == "IsShown" then
				return function() return self.shown end
			elseif key == "CreateTexture" then
				return function()
					local texture = newWidget("Texture")
					self.textures[#self.textures + 1] = texture
					return texture
				end
			elseif key == "SetTexture" then
				return function(_, file) self.file = file end
			elseif key == "SetHighlightTexture" then
				return function(_, file) self.highlight = file end
			elseif key == "SetMask" then
				return function(_, file) self.mask = file end
			elseif key == "GetWidth" then
				return function() return rawget(self, "width") or 140 end
			elseif key == "GetCenter" then
				return function() return 500, 400 end
			elseif key == "GetEffectiveScale" then
				return function() return 2 end
			end
			return function() end
		end,
	})
end

local function load(settings)
	_G.Minimap = newWidget("Minimap", "Minimap")
	_G.CreateFrame = function(kind, name, parent)
		return newWidget(kind, name, parent)
	end
	local ns = {}
	ns.Store = {
		saved = settings or {},
		GetSettings = function() return ns.Store.saved end,
		PutSetting = function(name, value) ns.Store.saved[name] = value return true end,
	}
	helper.loadAddonFile("LegacyNext/UI/MinimapButton.lua", ns)
	return ns
end

describe("MinimapButton", function()
	after_each(function()
		for _, name in ipairs({ "Minimap", "CreateFrame", "GameTooltip", "GetCursorPosition", "GetTime",
			"InCombatLockdown", "issecretvalue" }) do
			_G[name] = nil
		end
	end)

	it("loads without creating anything", function()
		local ns = load()
		assert.is_nil(ns.MinimapButton.button)
	end)

	it("puts a named button on the minimap's edge at the default angle", function()
		local ns = load()

		assert.is_true(ns.MinimapButton.Init())
		local button = ns.MinimapButton.button
		assert.equals("LegacyNextMinimapButton", button.name)
		assert.equals(_G.Minimap, button.parent)
		assert.is_true(button.shown)
		local x, y = ns.MinimapButton.Offset(ns.MinimapButton.DEFAULT_ANGLE, 70 + ns.MinimapButton.EDGE)
		assert.same({ "CENTER", _G.Minimap, "CENTER", x, y }, button.point)
	end)

	it("says why when there is no minimap", function()
		local ns = load()
		_G.Minimap = nil

		local ok, reason = ns.MinimapButton.Init()

		assert.is_nil(ok)
		assert.equals("no Minimap frame", reason)
	end)

	it("comes back at the saved angle, and hidden when saved hidden", function()
		local ns = load({ minimapAngle = 90, minimapHidden = true })

		ns.MinimapButton.Init()
		local button = ns.MinimapButton.button

		assert.is_false(button.shown)
		local x, y = ns.MinimapButton.Offset(90, 70 + ns.MinimapButton.EDGE)
		assert.same({ "CENTER", _G.Minimap, "CENTER", x, y }, button.point)
	end)

	it("falls back to the default angle when the save is junk", function()
		local ns = load({ minimapAngle = "east" })

		ns.MinimapButton.Init()

		local x, y = ns.MinimapButton.Offset(ns.MinimapButton.DEFAULT_ANGLE, 70 + ns.MinimapButton.EDGE)
		assert.same({ "CENTER", _G.Minimap, "CENTER", x, y }, ns.MinimapButton.button.point)
	end)

	it("hides and shows, and saves the choice", function()
		local ns = load()
		ns.MinimapButton.Init()

		ns.MinimapButton.SetHidden(true)
		assert.is_false(ns.MinimapButton.button.shown)
		assert.is_true(ns.Store.saved.minimapHidden)
		assert.is_true(ns.MinimapButton.IsHidden())

		ns.MinimapButton.SetHidden(false)
		assert.is_true(ns.MinimapButton.button.shown)
		assert.is_false(ns.Store.saved.minimapHidden)
	end)

	it("saves a hide made before the button exists, and applies it on Init", function()
		local ns = load()

		ns.MinimapButton.SetHidden(true)
		ns.MinimapButton.Init()

		assert.is_false(ns.MinimapButton.button.shown)
	end)

	it("returns write failures without changing visibility or lock state", function()
		local ns = load()
		ns.MinimapButton.Init()
		ns.Store.PutSetting = function() return false, "saved schema 2, this build reads 1" end

		local ok, reason = ns.MinimapButton.SetHidden(true)
		assert.is_false(ok)
		assert.equals("saved schema 2, this build reads 1", reason)
		assert.is_true(ns.MinimapButton.button.shown)
		assert.is_false(ns.MinimapButton.IsHidden())
		ok, reason = ns.MinimapButton.SetLocked(true)
		assert.is_false(ok)
		assert.equals("saved schema 2, this build reads 1", reason)
		assert.is_false(ns.MinimapButton.IsLocked())
	end)

	it("returns a reason when there is no settings writer", function()
		local ns = load()
		ns.Store.PutSetting = nil

		local ok, reason = ns.MinimapButton.SetHidden(true)

		assert.is_nil(ok)
		assert.equals("Store.PutSetting missing", reason)
	end)

	it("notifies settings after successful visibility and lock changes", function()
		local ns = load()
		local changes = {}
		ns.Options = { NotifyChanged = function(key) changes[#changes + 1] = key end }

		assert.is_true(ns.MinimapButton.SetHidden(true))
		assert.is_true(ns.MinimapButton.SetLocked(true))
		assert.same({ "minimapHidden", "minimapLocked" }, changes)
	end)

	it("checks secrecy before rejecting a non-finite number", function()
		local ns = load({ minimapAngle = math.huge })
		local checked = false
		_G.issecretvalue = function(value)
			if value == math.huge then checked = true return true end
			return false
		end

		assert.is_true(ns.MinimapButton.Init())
		assert.is_true(checked)
		assert.equals(ns.MinimapButton.DEFAULT_ANGLE, ns.MinimapButton.button.angle)
	end)

	it("rejects numbers safely when the secrecy check throws", function()
		local ns = load({ minimapAngle = 90 })
		_G.issecretvalue = function() error("guard unavailable") end

		assert.has_no.errors(function() ns.MinimapButton.Init() end)
		assert.equals(ns.MinimapButton.DEFAULT_ANGLE, ns.MinimapButton.button.angle)
	end)

	describe("angles", function()
		it("puts 0 degrees to the right and 90 at the top", function()
			local ns = load()
			local x, y = ns.MinimapButton.Offset(0, 80)
			assert.near(80, x, 1e-9)
			assert.near(0, y, 1e-9)
			x, y = ns.MinimapButton.Offset(90, 80)
			assert.near(0, x, 1e-9)
			assert.near(80, y, 1e-9)
		end)

		it("reads the cursor's angle round the minimap's centre, in 0 to 360", function()
			local ns = load()
			assert.near(0, ns.MinimapButton.AngleOf(10, 0), 1e-9)
			assert.near(90, ns.MinimapButton.AngleOf(0, 10), 1e-9)
			assert.near(225, ns.MinimapButton.AngleOf(-10, -10), 1e-9)
		end)
	end)

	describe("dragging", function()
		it("follows the cursor in the minimap's scale and saves the angle on release", function()
			local ns = load()
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button
			-- Minimap centre (500, 400) at effective scale 2: a cursor at (1000, 1000) screen
			-- pixels is (500, 500), straight above the centre.
			_G.GetCursorPosition = function() return 1000, 1000 end

			button.script_OnDragStart(button)
			button.script_OnUpdate(button)
			button.script_OnDragStop(button)

			assert.near(90, ns.Store.saved.minimapAngle, 1e-9)
			assert.is_nil(rawget(button, "script_OnUpdate"))
			local x, y = ns.MinimapButton.Offset(90, 70 + ns.MinimapButton.EDGE)
			assert.same({ "CENTER", _G.Minimap, "CENTER", x, y }, button.point)
		end)

		it("does not move while locked", function()
			local ns = load({ minimapLocked = true })
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button
			_G.GetCursorPosition = function() return 1000, 1000 end

			button.script_OnDragStart(button)

			assert.is_nil(rawget(button, "script_OnUpdate"))
			assert.is_nil(ns.Store.saved.minimapAngle)
		end)

		it("leaves the angle alone when cursor geometry is secret", function()
			local ns = load()
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button
			_G.GetCursorPosition = function() return 1000, 1000 end
			_G.issecretvalue = function(value) return value == 1000 end

			button.script_OnDragStart(button)
			button.script_OnUpdate(button)
			button.script_OnDragStop(button)

			assert.equals(ns.MinimapButton.DEFAULT_ANGLE, ns.Store.saved.minimapAngle)
		end)

		it("restores the saved angle and reports a rejected drag write", function()
			local ns = load({ minimapAngle = 45 })
			local said = {}
			ns.say = function(text) said[#said + 1] = text end
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button
			ns.Store.PutSetting = function() return false, "read-only" end
			_G.GetCursorPosition = function() return 1000, 1000 end

			button.script_OnDragStart(button)
			button.script_OnUpdate(button)
			button.script_OnDragStop(button)

			assert.equals(45, button.angle)
			assert.equals(45, ns.Store.saved.minimapAngle)
			assert.equals("could not save minimap position: read-only", said[1])
		end)
	end)

	describe("clicks", function()
		it("toggles the window on a left click and opens the settings on a right click", function()
			local ns = load()
			local done = {}
			ns.UI = { Toggle = function() done[#done + 1] = "toggle" end }
			ns.Options = { Open = function() done[#done + 1] = "settings" end }
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button

			button.script_OnClick(button, "LeftButton")
			button.script_OnClick(button, "RightButton")

			assert.same({ "toggle", "settings" }, done)
		end)
	end)

	describe("tooltip", function()
		local lines

		local function stubTooltip()
			lines = {}
			_G.GameTooltip = {
				SetOwner = function() end,
				AddLine = function(_, text) lines[#lines + 1] = text end,
				AddDoubleLine = function(_, left, right) lines[#lines + 1] = left .. " | " .. right end,
				Show = function() end,
				Hide = function() end,
			}
		end

		local function summary()
			return { lines = {
				{ kind = "header", text = "Legacy Track" },
				{ kind = "challenge", left = "Journeyman Alchemist", right = "0/150" },
				{ kind = "more", text = "and 8 more" },
			} }
		end

		it("draws the summary between the title and the click hints", function()
			stubTooltip()
			local ns = load()
			ns.MinimapButton.SetSummarySource(summary)
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button

			button.script_OnEnter(button)

			assert.equals("LegacyNext", lines[1])
			assert.equals("Legacy Track", lines[2])
			assert.equals("Journeyman Alchemist | 0/150", lines[3])
			assert.equals("and 8 more", lines[4])
			assert.equals(ns.MinimapButton.HINT, lines[5])
		end)

		it("reads once and reuses the summary inside the cache window", function()
			stubTooltip()
			local now = 100
			_G.GetTime = function() return now end
			local reads = 0
			local ns = load()
			ns.MinimapButton.SetSummarySource(function() reads = reads + 1 return summary() end)
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button

			button.script_OnEnter(button)
			now = 100 + ns.MinimapButton.SUMMARY_TTL - 1
			button.script_OnEnter(button)
			assert.equals(1, reads)

			now = 100 + ns.MinimapButton.SUMMARY_TTL + 1
			button.script_OnEnter(button)
			assert.equals(2, reads)
		end)

		it("does not read in combat, and says when it will", function()
			stubTooltip()
			_G.InCombatLockdown = function() return true end
			local reads = 0
			local ns = load()
			ns.MinimapButton.SetSummarySource(function() reads = reads + 1 return summary() end)
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button

			button.script_OnEnter(button)

			assert.equals(0, reads)
			assert.equals(ns.MinimapButton.COMBAT_LINE, lines[2])
		end)

		it("draws the same summary on another owner, with that surface's hint", function()
			stubTooltip()
			local owner
			_G.GameTooltip.SetOwner = function(_, frame) owner = frame end
			local ns = load()
			ns.MinimapButton.SetSummarySource(summary)
			local entry = newWidget("Button", "CompartmentEntry")

			ns.MinimapButton.ShowTooltip(entry, "Click to open or close.")

			assert.equals(entry, owner)
			assert.equals("LegacyNext", lines[1])
			assert.equals("Journeyman Alchemist | 0/150", lines[3])
			assert.equals("Click to open or close.", lines[#lines])
		end)

		it("keeps the hints when the read throws", function()
			stubTooltip()
			local ns = load()
			ns.MinimapButton.SetSummarySource(function() error("boom") end)
			ns.MinimapButton.Init()
			local button = ns.MinimapButton.button

			assert.has_no.errors(function() button.script_OnEnter(button) end)
			assert.equals("LegacyNext", lines[1])
			assert.equals(ns.MinimapButton.HINT, lines[#lines])
		end)
	end)

	it("describes itself for /lgn uidump", function()
		local ns = load({ minimapAngle = 90 })
		assert.same({ created = false }, ns.MinimapButton.Describe())

		ns.MinimapButton.Init()
		local described = ns.MinimapButton.Describe()

		assert.is_true(described.created)
		assert.is_true(described.shown)
		assert.equals(90, described.angle)
		assert.is_false(described.locked)
	end)
end)
