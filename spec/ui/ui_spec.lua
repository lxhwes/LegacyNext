local helper = require("spec.spec_helper")

-- A permissive widget double, not a fixture: it records what UI/ asks widgets to display so
-- the render path can be checked against Model's view. It asserts nothing about the client's
-- frame API, and it cannot: any method name is accepted. What it does catch is UI/ reading
-- the wrong field off a row, mis-wiring the data source, or erroring on a state.
local created = {}

-- Methods whose calls are kept, in order, as { name, ...args } in widget.calls.
local RECORDED = {
	SetResizable = true, SetResizeBounds = true, SetMinResize = true, SetMaxResize = true,
	StartSizing = true, StopMovingOrSizing = true,
	SetNormalTexture = true, SetHighlightTexture = true, SetPushedTexture = true,
}

-- The argument lists of every recorded call to `method` on `widget`.
local function callsTo(widget, method)
	local found = {}
	for _, call in ipairs(rawget(widget, "calls") or {}) do
		if call[1] == method then
			found[#found + 1] = { unpack(call, 2) }
		end
	end
	return found
end

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
				-- What SetWidth or SetSize set, else 496, the list's width at the designed size.
				return function() return rawget(self, "width") or 496 end
			elseif key == "GetHeight" then
				return function() return rawget(self, "height") end
			elseif key == "SetWidth" then
				return function(_, width) self.width = width end
			elseif key == "SetSize" then
				return function(_, width, height) self.width, self.height = width, height end
			elseif RECORDED[key] then
				return function(_, ...)
					local calls = rawget(self, "calls") or {}
					calls[#calls + 1] = { key, ... }
					self.calls = calls
				end
			elseif key == "GetVerticalScrollRange" or key == "GetVerticalScroll" then
				return function() return 0 end
			elseif key == "SetScript" then
				return function(_, event, fn) self["script_" .. event] = fn end
			elseif key == "SetPoint" then
				return function(_, ...)
					local anchors = rawget(self, "anchors") or {}
					anchors[#anchors + 1] = { ... }
					self.anchors = anchors
				end
			elseif key == "ClearAllPoints" then
				return function() self.anchors = {} end
			elseif key == "SetHeight" then
				return function(_, height) self.height = height end
			elseif key == "EnableMouse" then
				return function(_, enabled) self.mouse = enabled end
			elseif key == "LockHighlight" or key == "UnlockHighlight" then
				return function() self.locked = key == "LockHighlight" end
			elseif key == "SetTexture" then
				-- nil clears it, so read it with rawget
				return function(_, texture) self.texture = texture end
			elseif key == "SetFontObject" then
				return function(_, font) self.font = font end
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
	_G.C_Timer = nil
	_G.InCombatLockdown = nil
	_G.LegacyNextDB = nil
	_G.LegacyNextCharDB = nil
	_G.PanelTemplates_SelectTab = nil
	_G.PanelTemplates_DeselectTab = nil
	_G.PanelTemplates_TabResize = nil
	_G.RAID_CLASS_COLORS = nil
	_G.C_ClassColor = nil
	_G.GameFontNormal = nil
	_G.GameFontHighlight = nil
end

-- A C_Timer double that holds callbacks until the test runs them, so ordering is explicit.
local function fakeTimer()
	local pending = {}
	_G.C_Timer = {
		After = function(delay, fn) pending[#pending + 1] = { delay = delay, fn = fn } end,
	}
	return pending
end


local function fixture(name)
	return dofile("spec/fixtures/" .. name .. ".lua")
end

local function pageOneSource(counter)
	return function()
		counter.calls = counter.calls + 1
		return { challenges = fixture("dump_challenges_page1_fresh").challenges }
	end
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
		assert.equals(2, #frame.dividers)
		assert.equals("not started", frame.dividers[1].label.text)
		assert.equals("no progress shown", frame.dividers[2].label.text)

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
	it("shows an error state instead of throwing when the data source errors", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function() error("attempt to index a number value") end)

		assert.has_no.errors(function() ns.UI.Show() end)
		local frame = ns.UI.frame
		assert.is_true(frame.status.shown)
		assert.matches("^Could not read your challenges: .*attempt to index a number value", frame.status.text)
	end)

	it("forgets a filter whose group has gone", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function()
			return { challenges = fixture("dump_challenges_page1_fresh").challenges }
		end)
		ns.UI.Show()
		ns.UI.SetFilter(123456)

		assert.is_nil(ns.UI.filter)
		assert.is_nil(ns.UI.view.filter)
	end)

	it("waits for combat to end before the first read", function()
		local ns = loadUI()
		local counter = { calls = 0 }
		ns.UI.SetDataSource(pageOneSource(counter))
		local inCombat = true
		_G.InCombatLockdown = function() return inCombat end

		ns.UI.Show()
		assert.equals(0, counter.calls)
		assert.is_true(ns.UI.frame.status.shown)
		assert.matches("combat", ns.UI.frame.status.text)

		inCombat = false
		ns.UI.frame.script_OnEvent(ns.UI.frame, "PLAYER_REGEN_ENABLED")
		assert.equals(1, counter.calls)
		assert.equals(11, #ns.UI.frame.rows)
	end)

	it("coalesces CRITERIA_UPDATE over 5 s and lets ACHIEVEMENT_EARNED cut in at 1 s", function()
		local ns = loadUI()
		local pending = fakeTimer()
		local counter = { calls = 0 }
		ns.UI.SetDataSource(pageOneSource(counter))
		ns.UI.Show()
		assert.equals(1, counter.calls)
		local onEvent = ns.UI.frame.script_OnEvent

		onEvent(ns.UI.frame, "CRITERIA_UPDATE")
		onEvent(ns.UI.frame, "CRITERIA_UPDATE")
		assert.equals(1, #pending)
		assert.equals(5, pending[1].delay)

		onEvent(ns.UI.frame, "ACHIEVEMENT_EARNED")
		assert.equals(2, #pending)
		assert.equals(1, pending[2].delay)

		pending[2].fn()
		assert.equals(2, counter.calls)
		pending[1].fn() -- superseded by the 1 s refresh, so it reads nothing
		assert.equals(2, counter.calls)

		onEvent(ns.UI.frame, "CRITERIA_UPDATE")
		assert.equals(3, #pending)
		pending[3].fn()
		assert.equals(3, counter.calls)
	end)

	it("shows how many other-class rows are hidden", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function()
			return {
				challenges = fixture("dump_challenges_page1_fresh").challenges,
				categories = fixture("categories_full").categories,
				character = fixture("dump_character_shaman").character,
			}
		end)
		ns.UI.Show()

		assert.is_true(ns.UI.frame.status.shown)
		assert.equals("3 other-class challenges hidden", ns.UI.frame.status.text)
	end)

	-- The status line was anchored once, at the top of the list, so a footnote printed over the
	-- first two rows.
	it("draws the footnote below the last row", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function()
			return {
				challenges = fixture("dump_challenges_page1_fresh").challenges,
				categories = fixture("categories_full").categories,
				character = fixture("dump_character_shaman").character,
			}
		end)
		ns.UI.Show()

		local top
		for _, anchor in ipairs(ns.UI.frame.status.anchors) do
			if anchor[1] == "TOPLEFT" then top = anchor[3] end
		end
		assert.equals(-(#ns.UI.view.rows * 16 + 4), top)
	end)

	-- 28 px a line is an estimate, and a note that wraps outgrows it: the scroll range ended
	-- before the note did. The double has no GetStringHeight until the test gives it one.
	it("sizes the list to the footnote's wrapped height when the client can measure it", function()
		local ns = loadUI()
		ns.UI.SetDataSource(function()
			return {
				challenges = fixture("dump_challenges_page1_fresh").challenges,
				categories = fixture("categories_full").categories,
				character = fixture("dump_character_shaman").character,
			}
		end)
		ns.UI.Show()
		local frame = ns.UI.frame
		local rowsHeight = #ns.UI.view.rows * 16
		assert.equals(rowsHeight + 12 + 28, frame.listChild.height)

		rawset(frame.status, "GetStringHeight", function() return 90 end)
		ns.UI.Refresh()

		assert.equals(rowsHeight + 12 + 90, frame.listChild.height)
	end)

	it("waits for combat to end before reading a filter change", function()
		local ns = loadUI()
		local counter = { calls = 0 }
		ns.UI.SetDataSource(pageOneSource(counter))
		local inCombat = false
		_G.InCombatLockdown = function() return inCombat end
		ns.UI.Show()

		inCombat = true
		ns.UI.SetFilter(123)
		assert.equals(1, counter.calls)
		assert.matches("combat", ns.UI.frame.status.text)

		inCombat = false
		ns.UI.frame.script_OnEvent(ns.UI.frame, "PLAYER_REGEN_ENABLED")
		assert.equals(2, counter.calls)
	end)

	-- Views built by hand in the shape Model hands over: row.icon and header.icon are a texture
	-- file id, a path or nil, and a character row's classToken is a string or nil.
	describe("icons and class colours", function()
		local MEDIA = "Interface\\AddOns\\LegacyNext\\Media\\icon"

		local function view(rows, headerIcon)
			return { header = { lines = { "Legacy Track", "Next: Reward" }, icon = headerIcon, state = "ok" },
				filters = {}, rows = rows, state = "ok" }
		end
		local function challenge(name, icon)
			return { kind = "challenge", name = name, progressText = "1/2", pointsText = "1", measurable = true,
				icon = icon }
		end
		local function tradeskill(name, icon)
			return { kind = "tradeskill", name = name, progressText = "75/150", pointsText = "1", measurable = true,
				icon = icon }
		end
		local function character(name, classToken, current)
			return { kind = "character", name = name, progressText = "0/0/0", pointsText = "0", measurable = true,
				classToken = classToken, current = current }
		end
		local function heading(name)
			return { kind = "columns", name = name, progressText = "P/A/R", pointsText = "Free" }
		end

		local function nameLeft(row)
			for _, anchor in ipairs(row.name.anchors) do
				if anchor[1] == "LEFT" then return anchor[2] end
			end
		end

		it("draws a row's icon left of its name, and keeps names aligned without one", function()
			local ns = loadUI()

			ns.UI.Render(view({ challenge("A", 1001), challenge("B", nil), challenge("C", MEDIA) }))

			local rows = ns.UI.frame.rows
			assert.equals(1001, rawget(rows[1].icon, "texture"))
			assert.is_true(rows[1].icon.shown)
			assert.is_false(rows[2].icon.shown)
			assert.is_nil(rawget(rows[2].icon, "texture"))
			assert.equals(MEDIA, rawget(rows[3].icon, "texture"))
			assert.is_true(nameLeft(rows[1]) > 0)
			assert.equals(nameLeft(rows[1]), nameLeft(rows[2]))
			assert.equals(nameLeft(rows[1]), nameLeft(rows[3]))
		end)

		it("leaves names where they were when no row has an icon", function()
			local ns = loadUI()

			ns.UI.Render(view({ challenge("A"), challenge("B") }))

			for _, row in ipairs(ns.UI.frame.rows) do
				assert.equals(0, nameLeft(row))
				assert.is_false(row.icon.shown)
			end
		end)

		it("draws the next reward's icon before header line 2, and drops it when there is none", function()
			local ns = loadUI()

			ns.UI.Render(view({ challenge("A") }, 2002))
			local frame = ns.UI.frame
			assert.equals(2002, rawget(frame.headerIcon, "texture"))
			assert.is_true(frame.headerIcon.shown)
			assert.same({ "LEFT", frame.headerIcon, "RIGHT", 4, 0 }, frame.headerLines[2].anchors[1])
			assert.equals("Next: Reward", frame.headerLines[2].text)

			ns.UI.Render(view({ challenge("A") }))
			assert.is_false(frame.headerIcon.shown)
			assert.is_nil(rawget(frame.headerIcon, "texture"))
			assert.same({ "TOPLEFT", frame.headerLines[1], "BOTTOMLEFT", 0, -4 }, frame.headerLines[2].anchors[1])
		end)

		it("colours a character's name by class and tints the current row", function()
			_G.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.5, b = 0 } }
			local ns = loadUI()

			ns.UI.Render(view({ heading("Character"), character("Ann  L10 Druid", "DRUID", true),
				character("Bob  L5 Mage", "MAGE", false), character("Cy  L1", nil, false) }))

			local rows = ns.UI.frame.rows
			assert.equals("Character", rows[1].name.text)
			assert.is_false(rows[1].tint.shown)
			assert.equals("|cffff8000Ann  L10 Druid|r", rows[2].name.text)
			assert.is_true(rows[2].tint.shown)
			assert.equals("Bob  L5 Mage", rows[3].name.text)
			assert.is_false(rows[3].tint.shown)
			assert.equals("Cy  L1", rows[4].name.text)
			for _, row in ipairs(rows) do
				assert.equals(0, nameLeft(row))
				assert.is_false(row.icon.shown)
			end
		end)

		it("asks C_ClassColor for a class RAID_CLASS_COLORS lacks, and survives it throwing", function()
			_G.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.5, b = 0 } }
			_G.C_ClassColor = {
				GetClassColor = function(token)
					if token == "PRIEST" then error("bad class") end
					if token == "MAGE" then return { r = 0, g = 0.5, b = 1 } end
				end,
			}
			local ns = loadUI()

			ns.UI.Render(view({ character("Bob", "MAGE", false), character("Pat", "PRIEST", false),
				character("Sam", "SHAMAN", false) }))

			local rows = ns.UI.frame.rows
			assert.equals("|cff0080ffBob|r", rows[1].name.text)
			assert.equals("Pat", rows[2].name.text)
			assert.equals("Sam", rows[3].name.text)
		end)

		it("keeps today's look with no class colour: the current character in gold, no tint", function()
			_G.GameFontNormal = { font = "GameFontNormal" }
			_G.GameFontHighlight = { font = "GameFontHighlight" }
			local ns = loadUI()

			ns.UI.Render(view({ character("Ann", "DRUID", true), character("Bob", "MAGE", false) }))

			local rows = ns.UI.frame.rows
			assert.equals("Ann", rows[1].name.text)
			assert.equals(_G.GameFontNormal, rows[1].name.font)
			assert.is_false(rows[1].tint.shown)
			assert.equals(_G.GameFontHighlight, rows[2].name.font)
		end)

		it("draws a tradeskill row's icon, with the roster's other rows left as they are", function()
			local ns = loadUI()

			ns.UI.Render(view({ heading("Character"), character("Ann", nil, true),
				heading("Tradeskill challenge"), tradeskill("Journeyman Alchemist  Ann", 3003) }))

			local rows = ns.UI.frame.rows
			assert.equals(3003, rawget(rows[4].icon, "texture"))
			assert.is_true(rows[4].icon.shown)
			assert.is_true(nameLeft(rows[4]) > 0)
			for index = 1, 3 do
				assert.equals(0, nameLeft(rows[index]))
				assert.is_false(rows[index].icon.shown)
			end
		end)

		-- Rows are pooled across tabs and redraws.
		it("never leaves a stale icon, colour or tint on a reused row", function()
			_G.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.5, b = 0 } }
			local ns = loadUI()
			ns.UI.Render(view({ heading("Character"), character("Ann", "DRUID", true),
				heading("Tradeskill challenge"), tradeskill("Journeyman Alchemist  Ann", 3003) }, 2002))
			local rows = ns.UI.frame.rows

			ns.UI.Render(view({ challenge("A"), challenge("B"), challenge("C"), challenge("D") }))

			assert.equals(4, #rows)
			for index, row in ipairs(rows) do
				assert.equals(({ "A", "B", "C", "D" })[index], row.name.text)
				assert.is_false(row.tint.shown)
				assert.is_false(row.icon.shown)
				assert.is_nil(rawget(row.icon, "texture"))
				assert.equals(0, nameLeft(row))
			end
			assert.is_false(ns.UI.frame.headerIcon.shown)

			ns.UI.Render(view({ challenge("A", 1001), challenge("B", 1002) }))
			ns.UI.Render(view({ heading("Character"), character("Bob", "MAGE", false) }))

			for index = 1, 2 do
				assert.is_false(rows[index].icon.shown)
				assert.equals(0, nameLeft(rows[index]))
			end
			assert.equals("Bob", rows[2].name.text)
		end)
	end)

	describe("window state", function()
		local categories = fixture("categories_full").categories
		local tradeskills
		for _, category in ipairs(categories) do
			if category.name == "Tradeskills" then tradeskills = category.id end
		end

		-- Plays the client: this character's saved table is assigned before ADDON_LOADED, when
		-- Core attaches the store. UIParent gets a screen size the clamp can read.
		local function loadWithStore(saved)
			_G.LegacyNextCharDB = saved
			local ns = loadUI()
			helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
			helper.loadAddonFile("LegacyNext/Store/Store.lua", ns)
			ns.Store.Attach()
			rawset(_G.UIParent, "GetWidth", function() return 1920 end)
			rawset(_G.UIParent, "GetHeight", function() return 1080 end)
			ns.UI.SetDataSource(function()
				return {
					challenges = fixture("dump_challenges_page1_fresh").challenges,
					categories = categories,
					snapshots = {},
				}
			end)
			return ns
		end

		local function shownNames(frame)
			local names = {}
			for _, row in ipairs(frame.rows) do
				if row.shown then names[#names + 1] = row.name.text end
			end
			return names
		end

		it("restores the saved filter and position on the first open", function()
			local ns = loadWithStore({ ui = { filter = tradeskills, point = { left = 100, top = 700 } } })

			ns.UI.Show()

			assert.equals(tradeskills, ns.UI.view.filter)
			assert.same({ "Journeyman Alchemist", "Expert Alchemist", "Artisan Alchemist" }, shownNames(ns.UI.frame))
			assert.same({ "TOPLEFT", _G.UIParent, "BOTTOMLEFT", 100, 700 }, ns.UI.frame.anchors[1])
		end)

		it("restores the saved tab", function()
			local ns = loadWithStore({ ui = { tab = "roster" } })

			ns.UI.Show()

			assert.equals("roster", ns.UI.Describe().tab)
			assert.equals("roster", ns.UI.view.tab)
			assert.is_true(ns.UI.frame.tabs[2].locked)
		end)

		it("ignores a saved tab it does not know", function()
			local ns = loadWithStore({ ui = { tab = "bogus" } })

			ns.UI.Show()

			assert.equals("nextup", ns.UI.tab)
		end)

		-- Category ids churn between beta builds, so a saved one can name nothing.
		it("falls back to All when the saved filter's category has gone", function()
			local ns = loadWithStore({ ui = { filter = 999999 } })

			assert.has_no.errors(function() ns.UI.Show() end)

			assert.equals("ok", ns.UI.view.state)
			assert.is_nil(ns.UI.view.filter)
			assert.is_nil(ns.UI.filter)
			assert.equals(11, #shownNames(ns.UI.frame))
			assert.is_true(ns.UI.frame.filterBar.buttons[1].locked)
		end)

		it("saves the tab, the filter and the position as they change", function()
			local ns = loadWithStore(nil)
			ns.UI.Show()
			local frame = ns.UI.frame

			ns.UI.SetTab("roster")
			assert.equals("roster", _G.LegacyNextCharDB.ui.tab)
			ns.UI.SetTab("nextup")
			assert.equals("nextup", _G.LegacyNextCharDB.ui.tab)

			ns.UI.SetFilter(tradeskills)
			assert.equals(tradeskills, _G.LegacyNextCharDB.ui.filter)
			ns.UI.SetFilter(nil)
			assert.is_nil(_G.LegacyNextCharDB.ui.filter)

			rawset(frame, "GetLeft", function() return 40.5 end)
			rawset(frame, "GetTop", function() return 600 end)
			frame.script_OnDragStop(frame)
			assert.same({ left = 40.5, top = 600 }, _G.LegacyNextCharDB.ui.point)
		end)

		it("saves no position when the frame cannot say where it is", function()
			local ns = loadWithStore(nil)
			ns.UI.Show()

			ns.UI.frame.script_OnDragStop(ns.UI.frame)

			assert.is_nil(_G.LegacyNextCharDB and _G.LegacyNextCharDB.ui and _G.LegacyNextCharDB.ui.point)
		end)

		it("clamps a saved position onto the screen", function()
			local ns = loadWithStore({ ui = { point = { left = 5000, top = -50 } } })

			ns.UI.Show()

			-- 1920 - 520 wide, and the top no lower than the frame's 480 height.
			assert.same({ "TOPLEFT", _G.UIParent, "BOTTOMLEFT", 1400, 480 }, ns.UI.frame.anchors[1])
		end)

		it("centres the frame when the saved position is unusable", function()
			for _, point in ipairs({ "junk", { left = "x", top = 5 }, { left = 0 / 0, top = 5 },
				{ left = 5, top = math.huge }, { top = 5 } }) do
				local ns = loadWithStore({ ui = { point = point } })

				ns.UI.Show()

				assert.same({ "CENTER" }, ns.UI.frame.anchors[1])
				unloadUI()
			end
		end)

		it("centres the frame when the screen size cannot be read", function()
			local ns = loadWithStore({ ui = { point = { left = 100, top = 700 } } })
			rawset(_G.UIParent, "GetHeight", function() return nil end)

			ns.UI.Show()

			assert.same({ "CENTER" }, ns.UI.frame.anchors[1])
		end)

		describe("size", function()
			-- Runs `patch` on the main frame as it is created, before UI.lua touches it, so a test
			-- can take a method away the way an older client would lack it.
			local function patchMainFrame(patch)
				local create = _G.CreateFrame
				_G.CreateFrame = function(kind, name, parent, template)
					local widget = create(kind, name, parent, template)
					if name == "LegacyNextFrame" then
						patch(widget)
					end
					return widget
				end
			end

			local function sizeOf(widget)
				return { rawget(widget, "width"), rawget(widget, "height") }
			end

			pending("restores the saved size and clamps the position with it", function()
				local ns = loadWithStore({ ui = { size = { width = 700, height = 600 },
					point = { left = 1500, top = 500 } } })

				ns.UI.Show()

				assert.same({ 700, 600 }, sizeOf(ns.UI.frame))
				-- 1920 - 700 wide, and the top no lower than the frame's 600 height.
				assert.same({ "TOPLEFT", _G.UIParent, "BOTTOMLEFT", 1220, 600 }, ns.UI.frame.anchors[1])
				local described = ns.UI.Describe()
				assert.equals(700, described.width)
				assert.equals(600, described.height)
			end)

			pending("clamps a saved size between the minimum and the screen", function()
				for _, case in ipairs({
					{ saved = { width = 100, height = 5000 }, want = { 400, 1080 } },
					{ saved = { width = 5000, height = 100 }, want = { 1920, 360 } },
					{ saved = { width = -20, height = 0 }, want = { 400, 360 } },
				}) do
					local ns = loadWithStore({ ui = { size = case.saved } })

					ns.UI.Show()

					assert.same(case.want, sizeOf(ns.UI.frame))
					unloadUI()
				end
			end)

			pending("keeps a saved size above the minimum when the screen cannot be read", function()
				local ns = loadWithStore({ ui = { size = { width = 3000, height = 100 } } })
				rawset(_G.UIParent, "GetWidth", function() return nil end)

				ns.UI.Show()

				assert.same({ 3000, 360 }, sizeOf(ns.UI.frame))
			end)

			pending("opens at 520x480 when the saved size is unusable", function()
				for _, size in ipairs({ "junk", { width = "x", height = 500 }, { width = 0 / 0, height = 500 },
					{ width = 600, height = math.huge }, { height = 500 } }) do
					local ns = loadWithStore({ ui = { size = size } })

					ns.UI.Show()

					assert.same({ 520, 480 }, sizeOf(ns.UI.frame))
					unloadUI()
				end
			end)

			pending("is resizable from 400x360 up to the screen, with Blizzard's grip", function()
				local ns = loadWithStore(nil)

				ns.UI.Show()
				local frame = ns.UI.frame

				assert.same({ { true } }, callsTo(frame, "SetResizable"))
				assert.same({ { 400, 360, 1920, 1080 } }, callsTo(frame, "SetResizeBounds"))
				assert.same({}, callsTo(frame, "SetMinResize"))
				local grip = frame.grip
				assert.equals("PanelResizeButtonTemplate", grip.template)
				assert.same({ "BOTTOMRIGHT", -2, 2 }, grip.anchors[1])
				-- The scroll bar's down button would sit under the grip at the old 12 px.
				assert.same({ "BOTTOMRIGHT", -34, 18 }, frame.scroll.anchors[2])
				local described = ns.UI.Describe()
				assert.equals("SetResizeBounds", described.resize)
				assert.equals("PanelResizeButtonTemplate", described.grip)
				assert.equals(520, described.width)
				assert.equals(480, described.height)
			end)

			pending("falls back to SetMinResize and SetMaxResize without SetResizeBounds", function()
				local ns = loadWithStore(nil)
				patchMainFrame(function(frame) rawset(frame, "SetResizeBounds", false) end)

				ns.UI.Show()
				local frame = ns.UI.frame

				assert.same({ { 400, 360 } }, callsTo(frame, "SetMinResize"))
				assert.same({ { 1920, 1080 } }, callsTo(frame, "SetMaxResize"))
				assert.same({ { true } }, callsTo(frame, "SetResizable"))
				assert.equals("SetMinResize", ns.UI.Describe().resize)
			end)

			pending("stays a fixed size, with no grip, when no bounds method exists", function()
				local ns = loadWithStore(nil)
				patchMainFrame(function(frame)
					rawset(frame, "SetResizeBounds", false)
					rawset(frame, "SetMinResize", false)
				end)

				ns.UI.Show()
				local frame = ns.UI.frame

				assert.same({}, callsTo(frame, "SetResizable"))
				assert.is_false(frame.grip)
				assert.same({ "BOTTOMRIGHT", -34, 12 }, frame.scroll.anchors[2])
				assert.equals("none", ns.UI.Describe().resize)
				assert.equals("none", ns.UI.Describe().grip)
			end)

			pending("stays a fixed size when setting the bounds throws", function()
				local ns = loadWithStore(nil)
				patchMainFrame(function(frame)
					rawset(frame, "SetResizeBounds", function() error("bad bounds") end)
				end)

				assert.has_no.errors(function() ns.UI.Show() end)

				assert.is_false(ns.UI.frame.grip)
				assert.equals("none", ns.UI.Describe().resize)
			end)

			pending("draws the grip with the chat size-grabber art when the template is missing", function()
				local ns = loadWithStore(nil)
				local create = _G.CreateFrame
				_G.CreateFrame = function(kind, name, parent, template)
					if template == "PanelResizeButtonTemplate" then error("unknown template") end
					return create(kind, name, parent, template)
				end

				ns.UI.Show()
				local grip = ns.UI.frame.grip

				assert.is_nil(rawget(grip, "template"))
				assert.same({ 16, 16 }, sizeOf(grip))
				assert.same({ { "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up" } }, callsTo(grip, "SetNormalTexture"))
				assert.same({ { "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight" } },
					callsTo(grip, "SetHighlightTexture"))
				assert.same({ { "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down" } }, callsTo(grip, "SetPushedTexture"))
				assert.equals("plain", ns.UI.Describe().grip)
			end)

			pending("sizes from the bottom-right corner and saves size and position on release", function()
				local ns = loadWithStore(nil)
				ns.UI.Show()
				local frame, grip = ns.UI.frame, ns.UI.frame.grip

				grip.script_OnMouseDown(grip, "LeftButton")
				assert.same({ { "BOTTOMRIGHT", true } }, callsTo(frame, "StartSizing"))
				assert.is_nil(_G.LegacyNextCharDB and _G.LegacyNextCharDB.ui and _G.LegacyNextCharDB.ui.size)

				frame:SetSize(640.5, 500)
				rawset(frame, "GetLeft", function() return 40 end)
				rawset(frame, "GetTop", function() return 900 end)
				grip.script_OnMouseUp(grip, "LeftButton")

				assert.equals(1, #callsTo(frame, "StopMovingOrSizing"))
				assert.same({ width = 640.5, height = 500 }, _G.LegacyNextCharDB.ui.size)
				-- A centred window has no saved corner; the restore needs one to keep the corner put.
				assert.same({ left = 40, top = 900 }, _G.LegacyNextCharDB.ui.point)
			end)

			pending("sizes only on the left button", function()
				local ns = loadWithStore(nil)
				ns.UI.Show()
				local frame, grip = ns.UI.frame, ns.UI.frame.grip

				grip.script_OnMouseDown(grip, "RightButton")
				grip.script_OnMouseUp(grip, "RightButton")

				assert.same({}, callsTo(frame, "StartSizing"))
				assert.same({}, callsTo(frame, "StopMovingOrSizing"))
				assert.is_nil(_G.LegacyNextCharDB and _G.LegacyNextCharDB.ui and _G.LegacyNextCharDB.ui.size)
			end)

			-- U2: the frame is not protected, so sizing it is allowed in combat.
			pending("sizes in combat", function()
				local ns = loadWithStore(nil)
				_G.InCombatLockdown = function() return true end
				ns.UI.Show()
				local frame, grip = ns.UI.frame, ns.UI.frame.grip

				grip.script_OnMouseDown(grip, "LeftButton")
				grip.script_OnMouseUp(grip, "LeftButton")

				assert.equals(1, #callsTo(frame, "StartSizing"))
				assert.equals(1, #callsTo(frame, "StopMovingOrSizing"))
				assert.same({ width = 520, height = 480 }, _G.LegacyNextCharDB.ui.size)
			end)

			pending("saves no size when the frame cannot say how big it is", function()
				local ns = loadWithStore(nil)
				ns.UI.Show()
				local frame, grip = ns.UI.frame, ns.UI.frame.grip
				rawset(frame, "GetWidth", function() return nil end)

				grip.script_OnMouseDown(grip, "LeftButton")
				grip.script_OnMouseUp(grip, "LeftButton")

				assert.is_nil(_G.LegacyNextCharDB and _G.LegacyNextCharDB.ui and _G.LegacyNextCharDB.ui.size)
			end)

			pending("stops sizing and saves when the window closes mid-drag", function()
				local ns = loadWithStore(nil)
				ns.UI.Show()
				local frame, grip = ns.UI.frame, ns.UI.frame.grip

				grip.script_OnMouseDown(grip, "LeftButton")
				frame:SetSize(600, 400)
				ns.UI.Hide()

				assert.equals(1, #callsTo(frame, "StopMovingOrSizing"))
				assert.same({ width = 600, height = 400 }, _G.LegacyNextCharDB.ui.size)
				grip.script_OnMouseUp(grip, "LeftButton") -- the release after it does nothing more
				assert.equals(1, #callsTo(frame, "StopMovingOrSizing"))
			end)

			describe("relayout", function()
				local function opened()
					local ns = loadWithStore(nil)
					local pending = fakeTimer()
					ns.UI.SetDataSource(function()
						return {
							challenges = fixture("dump_challenges_page1_fresh").challenges,
							categories = categories,
							character = fixture("dump_character_shaman").character,
						}
					end)
					ns.UI.Show()
					return ns, ns.UI.frame, pending
				end

				-- The double measures every filter button at 60 px, 64 with the gap.
				local function filterTops(frame)
					local tops = {}
					for index, button in ipairs(frame.filterBar.buttons) do
						tops[index] = button.anchors[1][3]
					end
					return tops
				end

				pending("follows the live width once per burst of size changes, without a read", function()
					local ns, frame, pending = opened()
					local reads = 0
					local source = ns.UI.source
					ns.UI.SetDataSource(function()
						reads = reads + 1
						return source()
					end)
					assert.equals(496, frame.listChild.width)
					assert.equals(496, frame.status.width)
					-- All plus the two groups the shaman's page 1 reaches.
					assert.equals(3, #frame.filterBar.buttons)
					assert.same({ 0, 0, 0 }, filterTops(frame))

					rawset(frame.scroll, "GetWidth", function() return 600 end)
					rawset(frame.filterBar, "GetWidth", function() return 130 end)
					for _ = 1, 3 do
						frame.script_OnSizeChanged(frame, 646, 480)
					end

					assert.equals(1, #pending)
					assert.equals(496, frame.listChild.width)
					pending[1].fn()

					assert.equals(600, frame.listChild.width)
					assert.equals(600, frame.status.width)
					-- Two buttons to a 130 px row, so the bar wraps onto a second.
					assert.same({ 0, 0, -26 }, filterTops(frame))
					assert.equals(0, reads)
				end)

				pending("re-measures the footnote at the new width", function()
					local _, frame, pending = opened()
					local rowsHeight = frame.listChild.height - 12 - 28
					rawset(frame.status, "GetStringHeight", function(self)
						return self.width < 300 and 60 or 20
					end)

					rawset(frame.scroll, "GetWidth", function() return 250 end)
					frame.script_OnSizeChanged(frame, 296, 480)
					pending[1].fn()

					assert.equals(rowsHeight + 12 + 60, frame.listChild.height)
				end)

				pending("leaves the layout alone when only the height changed", function()
					local _, frame, pending = opened()
					local cleared = 0
					local button = frame.filterBar.buttons[1]
					rawset(button, "ClearAllPoints", function(self)
						cleared = cleared + 1
						self.anchors = {}
					end)

					frame.script_OnSizeChanged(frame, 520, 700)
					pending[1].fn()

					assert.equals(0, cleared)
				end)

				pending("lays out at once on release, not after the timer", function()
					local _, frame = opened()
					local grip = frame.grip

					grip.script_OnMouseDown(grip, "LeftButton")
					rawset(frame.scroll, "GetWidth", function() return 700 end)
					grip.script_OnMouseUp(grip, "LeftButton")

					assert.equals(700, frame.listChild.width)
				end)

				pending("does nothing before the first view is drawn", function()
					local ns = loadWithStore(nil)
					local pending = fakeTimer()
					ns.UI.SetDataSource(nil)
					ns.UI.Show()
					local frame = ns.UI.frame

					rawset(frame.scroll, "GetWidth", function() return 600 end)
					assert.has_no.errors(function()
						frame.script_OnSizeChanged(frame, 646, 480)
						for _, entry in ipairs(pending) do entry.fn() end
					end)
				end)
			end)
		end)
	end)

	describe("roster tab", function()
		local categories = fixture("categories_full").categories

		local function loadWithRoster()
			local ns = loadUI()
			helper.loadAddonFile("LegacyNext/Model/Roster.lua", ns)
			return ns
		end

		local function shamanSource(ns)
			local shaman = ns.Model.BuildSnapshot({
				character = fixture("dump_character_shaman").character,
				treeSpend = fixture("dump_trees_fresh").treeSpend,
				now = 1000,
			})
			return function()
				return {
					challenges = fixture("dump_challenges_page1_fresh").challenges,
					categories = categories,
					snapshots = { shaman },
					currentKey = shaman.key,
					now = 1000,
				}
			end
		end

		local function shownNames(frame)
			local names = {}
			for _, row in ipairs(frame.rows) do
				if row.shown then
					names[#names + 1] = row.name.text
				end
			end
			return names
		end

		it("opens on Next Up, switches to the roster and back", function()
			local ns = loadWithRoster()
			ns.UI.SetDataSource(shamanSource(ns))
			ns.UI.Show()
			assert.equals("nextup", ns.UI.Describe().tab)
			local nextUp = shownNames(ns.UI.frame)

			ns.UI.SetTab("roster")
			local frame = ns.UI.frame
			assert.equals("roster", ns.UI.Describe().tab)
			assert.same({ "Character", "Bong Wrip  L1 Shaman" }, shownNames(frame))
			assert.equals("0/0/0", frame.rows[2].figure.text)
			assert.is_nil(rawget(frame.rows[1], "data")) -- a heading has no tooltip; raw, past the double
			assert.is_false(frame.rows[1].mouse)
			assert.is_true(frame.rows[2].mouse)
			assert.is_true(frame.tabs[2].locked)
			assert.is_false(frame.tabs[1].locked)
			for _, button in ipairs(frame.filterBar.buttons) do
				assert.is_false(button.shown)
			end

			ns.UI.SetTab("nextup")
			assert.same(nextUp, shownNames(frame))
			assert.is_true(frame.rows[1].mouse) -- the pooled heading row is a challenge row again
			assert.is_true(frame.tabs[1].locked)
		end)

		it("waits for combat to end before reading a tab switch", function()
			local ns = loadWithRoster()
			local source, reads = shamanSource(ns), 0
			ns.UI.SetDataSource(function()
				reads = reads + 1
				return source()
			end)
			local inCombat = false
			_G.InCombatLockdown = function() return inCombat end
			ns.UI.Show()

			inCombat = true
			ns.UI.SetTab("roster")
			assert.equals(1, reads)
			assert.matches("combat", ns.UI.frame.status.text)
			assert.is_true(ns.UI.frame.tabs[2].locked)

			inCombat = false
			ns.UI.frame.script_OnEvent(ns.UI.frame, "PLAYER_REGEN_ENABLED")
			assert.equals(2, reads)
			assert.same({ "Character", "Bong Wrip  L1 Shaman" }, shownNames(ns.UI.frame))
		end)

		-- Both tabs draw the same header, already read. Blanking it, and the filter bar with it,
		-- left nothing to click until combat ended.
		it("keeps the header and the filter bar while a switch waits for combat", function()
			local ns = loadWithRoster()
			local source = shamanSource(ns)
			ns.UI.SetDataSource(function()
				local input = source()
				input.rewardTrack = fixture("dump_rewards_fresh").rewardTrack
				return input
			end)
			local inCombat = false
			_G.InCombatLockdown = function() return inCombat end
			ns.UI.Show()
			local frame = ns.UI.frame
			local header = frame.headerLines[1].text
			local buttons = frame.filterBar.buttons
			assert.equals(4, #buttons)

			inCombat = true
			ns.UI.SetFilter(buttons[2].groupId)

			assert.matches("combat", frame.status.text)
			assert.equals(header, frame.headerLines[1].text)
			for index, button in ipairs(buttons) do
				assert.is_true(button.shown, button.text)
				assert.equals(index == 2, button.locked, button.text)
			end

			ns.UI.SetTab("roster")
			assert.equals(header, frame.headerLines[1].text)
			for _, button in ipairs(buttons) do
				assert.is_false(button.shown)
			end
			ns.UI.SetTab("nextup")
			assert.is_true(buttons[2].shown)
			assert.is_true(buttons[2].locked)
		end)

		it("redraws the roster after a snapshot, and leaves Next Up alone", function()
			local ns = loadWithRoster()
			local pending = fakeTimer()
			local source, reads = shamanSource(ns), 0
			ns.UI.SetDataSource(function()
				reads = reads + 1
				return source()
			end)
			ns.UI.Show()

			ns.UI.OnSnapshot()
			assert.equals(0, #pending)

			ns.UI.SetTab("roster")
			ns.UI.OnSnapshot()
			assert.equals(1, #pending)
			pending[1].fn()
			assert.equals(3, reads)
		end)

		it("keeps the footnote under an empty roster", function()
			local ns = loadWithRoster()
			ns.UI.SetDataSource(function() return { snapshots = { "junk" } } end)
			ns.UI.Show()

			ns.UI.SetTab("roster")

			assert.equals("No characters saved yet. Each character joins the roster when it logs in.\n"
				.. "1 saved character could not be read", ns.UI.frame.status.text)
		end)

		it("switches tab from the tab buttons", function()
			local ns = loadWithRoster()
			ns.UI.SetDataSource(shamanSource(ns))
			ns.UI.Show()
			local roster = ns.UI.frame.tabs[2]

			roster.script_OnClick(roster)

			assert.equals("roster", ns.UI.tab)
			assert.equals("Roster", roster.text)
		end)

		it("keeps the Next Up filter across a trip to the roster", function()
			local ns = loadWithRoster()
			ns.UI.SetDataSource(shamanSource(ns))
			local tradeskills
			for _, category in ipairs(categories) do
				if category.name == "Tradeskills" then tradeskills = category.id end
			end
			ns.UI.Show()
			ns.UI.SetFilter(tradeskills)

			ns.UI.SetTab("roster")
			ns.UI.SetTab("nextup")

			assert.equals(tradeskills, ns.UI.view.filter)
			assert.same({ "Journeyman Alchemist", "Expert Alchemist", "Artisan Alchemist" }, shownNames(ns.UI.frame))
		end)

		it("shows the roster's own error state when the read throws", function()
			local ns = loadWithRoster()
			local source, fail = shamanSource(ns), false
			ns.UI.SetDataSource(function()
				if fail then error("boom") end
				return source()
			end)
			ns.UI.Show()
			fail = true

			ns.UI.SetTab("roster")

			assert.is_true(ns.UI.frame.status.shown)
			assert.matches("^Could not read the roster: .*boom", ns.UI.frame.status.text)
		end)

		it("ignores an unknown tab", function()
			local ns = loadWithRoster()

			ns.UI.SetTab("bogus")

			assert.equals("nextup", ns.UI.tab)
		end)

		-- Today's selected tab is white text on the same red button, which reads faintly.
		describe("selected tab", function()
			local function stubTabHelpers()
				_G.PanelTemplates_SelectTab = function(tab) rawset(tab, "selected", true) end
				_G.PanelTemplates_DeselectTab = function(tab) rawset(tab, "selected", false) end
				local resized = {}
				_G.PanelTemplates_TabResize = function(tab, padding, absoluteSize, minWidth)
					resized[#resized + 1] = { tab = tab, padding = padding, absoluteSize = absoluteSize,
						minWidth = minWidth }
				end
				return resized
			end

			it("uses Blizzard's top tab and its select helpers when both are there", function()
				local resized = stubTabHelpers()
				local ns = loadWithRoster()
				ns.UI.SetDataSource(shamanSource(ns))
				ns.UI.Show()
				local tabs = ns.UI.frame.tabs

				assert.equals("PanelTopTabButtonTemplate", tabs[1].template)
				assert.equals("PanelTopTabButtonTemplate", tabs[2].template)
				assert.equals("PanelTopTabButtonTemplate", ns.UI.Describe().tabTemplate)
				assert.is_true(tabs[1].selected)
				assert.is_false(tabs[2].selected)
				assert.equals(2, #resized)
				assert.equals(80, resized[1].minWidth)
				-- The template resizes itself on show from the parent's minTabWidth.
				assert.equals(80, rawget(ns.UI.frame, "minTabWidth"))
				-- Widths follow the text, so each tab hangs off the one before it.
				assert.same({ "TOPLEFT", tabs[1], "TOPRIGHT", 4, 0 }, tabs[2].anchors[1])

				ns.UI.SetTab("roster")
				assert.is_false(tabs[1].selected)
				assert.is_true(tabs[2].selected)
			end)

			it("falls back to the panel button with a gold underline when the template fails", function()
				stubTabHelpers()
				local ns = loadWithRoster()
				local create = _G.CreateFrame
				_G.CreateFrame = function(kind, name, parent, template)
					if template == "PanelTopTabButtonTemplate" then error("unknown template") end
					return create(kind, name, parent, template)
				end
				ns.UI.SetDataSource(shamanSource(ns))
				ns.UI.Show()
				local tabs = ns.UI.frame.tabs

				assert.equals("UIPanelButtonTemplate", tabs[1].template)
				assert.equals("UIPanelButtonTemplate", ns.UI.Describe().tabTemplate)
				assert.is_nil(rawget(tabs[1], "selected"))
				assert.is_true(tabs[1].locked)
				assert.is_true(rawget(tabs[1], "underline").shown)
				assert.is_false(rawget(tabs[2], "underline").shown)

				ns.UI.SetTab("roster")
				assert.is_false(rawget(tabs[1], "underline").shown)
				assert.is_true(rawget(tabs[2], "underline").shown)
			end)

			it("falls back the same way when the select helpers are missing", function()
				local ns = loadWithRoster()
				ns.UI.SetDataSource(shamanSource(ns))
				ns.UI.Show()
				local tabs = ns.UI.frame.tabs

				assert.equals("UIPanelButtonTemplate", tabs[1].template)
				assert.is_true(rawget(tabs[1], "underline").shown)
				assert.is_false(rawget(tabs[2], "underline").shown)
			end)

			it("keeps the selection drawn when a select helper throws", function()
				stubTabHelpers()
				_G.PanelTemplates_SelectTab = function() error("GetAppropriateTooltip is nil") end
				local ns = loadWithRoster()
				ns.UI.SetDataSource(shamanSource(ns))

				assert.has_no.errors(function() ns.UI.Show() end)
				assert.is_true(ns.UI.frame.tabs[1].locked)
				assert.equals(11, #ns.UI.frame.rows)
			end)
		end)
	end)
end)
