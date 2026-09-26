local helper = require("spec.spec_helper")

-- A permissive widget double, not a fixture: it records what UI/ asks widgets to display so
-- the render path can be checked against Model's view. It asserts nothing about the client's
-- frame API, and it cannot: any method name is accepted. What it does catch is UI/ reading
-- the wrong field off a row, mis-wiring the data source, or erroring on a state.
local created = {}

local function newWidget(kind, name, template)
	local widget = { kind = kind, name = name, template = template, texts = {}, shown = true }
	setmetatable(widget, {
		__index = function(self, key)
			if key == "TitleText" or key == "CloseButton" or key == "ScrollBar" then
				return nil -- template children; absent on the double
			elseif key == "SetText" then
				return function(_, text) self.text = text end
			elseif key == "GetText" then
				return function() return self.text end
			elseif key == "Show" then
				-- Show and Hide fire their handlers on a state change, as the client does.
				-- A frame is shown at creation, so the first Hide() fires OnHide.
				return function()
					local was = self.shown
					self.shown = true
					if not was and self.script_OnShow then self.script_OnShow(self) end
				end
			elseif key == "Hide" then
				return function()
					local was = self.shown
					self.shown = false
					if was and self.script_OnHide then self.script_OnHide(self) end
				end
			elseif key == "IsShown" then
				return function() return self.shown end
			elseif key == "CreateFontString" or key == "CreateTexture" then
				return function() return newWidget(key) end
			elseif key == "GetFontString" then
				return function() return nil end
			elseif key == "GetWidth" then
				return function() return 496 end
			elseif key == "GetVerticalScrollRange" or key == "GetVerticalScroll" then
				return function() return 0 end
			elseif key == "SetScript" then
				return function(_, event, fn) self["script_" .. event] = fn end
			end
			return function() end
		end,
	})
	created[#created + 1] = widget
	return widget
end

local function loadUI()
	created = {}
	_G.CreateFrame = function(kind, name, _, template)
		return newWidget(kind, name, template)
	end
	_G.UIParent = newWidget("Frame", "UIParent")
	_G.UISpecialFrames = {}
	created = {} -- UIParent above is not the addon's doing

	local ns = helper.loadAddonFile("LegacyNext/Model/Model.lua")
	helper.loadAddonFile("LegacyNext/UI/UI.lua", ns)
	return ns
end

local function unloadUI()
	_G.CreateFrame = nil
	_G.UIParent = nil
	_G.UISpecialFrames = nil
end

local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

describe("UI", function()
	after_each(unloadUI)

	it("loads without creating anything", function()
		local ns = loadUI()
		assert.is_table(ns.UI)
		assert.equals(0, #created)
	end)

	-- ensureFrame used to publish UI.frame after frame:Hide(), and the Hide at creation fires
	-- OnHide, which indexes UI.frame. First /lgn in a session errored instead of opening.
	it("toggles open on the first call without touching a nil UI.frame", function()
		local ns = loadUI()
		assert.has_no.errors(function() ns.UI.Toggle() end)
		assert.is_true(ns.UI.frame:IsShown())
		assert.has_no.errors(function() ns.UI.Toggle() end)
		assert.is_false(ns.UI.frame:IsShown())
	end)

	it("renders the fixture view into rows that match Model's text", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function()
			return {
				challenges = fixture("dump_challenges_page1_fresh").challenges,
				rewardTrack = fixture("dump_rewards_fresh").rewardTrack,
				categories = fixture("categories_full").categories,
			}
		end)

		ns.UI.Show()
		local view = ns.UI.view
		local frame = ns.UI.frame

		assert.equals(view.header.lines[1], frame.headerLines[1].text)
		assert.equals("Next: Replica Ironforge Air Rifle", frame.headerLines[2].text)

		local expected = {}
		for _, row in ipairs(view.rows) do
			if row.kind == "challenge" then
				expected[#expected + 1] = row
			end
		end
		assert.equals(11, #expected)
		assert.equals(#expected, #frame.rows)
		for index, row in ipairs(expected) do
			assert.equals(row.name, frame.rows[index].name.text)
			assert.equals(row.progressText, frame.rows[index].figure.text)
			assert.equals(row.pointsText, frame.rows[index].points.text)
			assert.is_true(frame.rows[index].shown)
		end
		assert.equals(1, #frame.dividers)
		assert.equals("no progress shown", frame.dividers[1].label.text)

		-- Filter bar: All plus the three groups page 1 reaches.
		assert.equals(4, #frame.filterBar.buttons)
		assert.equals("All (11)", frame.filterBar.buttons[1].text)
		assert.equals("Classes (3)", frame.filterBar.buttons[2].text)
		assert.equals("LegacyNextFrame", _G.UISpecialFrames[1])
	end)

	it("shows the error state and hides stale rows", function()
		local ns = loadUI()
		local calls = 0
		ns.UI.SetDataSource(function()
			calls = calls + 1
			if calls == 1 then
				return { challenges = fixture("dump_challenges_page1_fresh").challenges }
			end
			return { challenges = nil, challengesReason = "GetCategoryList unavailable" }
		end)

		ns.UI.Show() -- OnShow refreshes: first read
		assert.equals(11, #ns.UI.frame.rows)

		ns.UI.Refresh()
		local frame = ns.UI.frame
		assert.is_true(frame.status.shown)
		assert.equals("Could not read your challenges: GetCategoryList unavailable", frame.status.text)
		for _, row in ipairs(frame.rows) do
			assert.is_false(row.shown)
		end
		assert.matches("unavailable", frame.headerLines[1].text)
	end)

	it("applies a filter through SetFilter", function()
		local ns = loadUI()
		local categories = fixture("categories_full").categories
		ns.UI.SetDataSource(function()
			return {
				challenges = fixture("dump_challenges_page1_fresh").challenges,
				categories = categories,
			}
		end)
		local tradeskills
		for _, category in ipairs(categories) do
			if category.name == "Tradeskills" then tradeskills = category.id end
		end

		ns.UI.Show()
		ns.UI.SetFilter(tradeskills)

		local shown = {}
		for _, row in ipairs(ns.UI.frame.rows) do
			if row.shown then shown[#shown + 1] = row.name.text end
		end
		assert.same({ "Journeyman Alchemist", "Expert Alchemist", "Artisan Alchemist" }, shown)
		assert.equals(tradeskills, ns.UI.view.filter)
	end)
end)
