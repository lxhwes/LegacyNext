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
	end)
end)
