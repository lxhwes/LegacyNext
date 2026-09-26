local _, ns = ...

-- The v0 frame. Reads from Model, never from Api: Core hands in a data source that returns
-- the Model.BuildView input, and everything drawn here comes out of that view. v0 is a
-- standalone frame; we do not hook Blizzard frames.
--
-- Templates and font objects are cited in docs/ui-templates.md at pin 70ef1b2. Every one is
-- feature-detected here anyway: a missing template falls back to a plain frame rather than an
-- error, because an error at load is a blank window Alex cannot debug interactively.
ns.UI = ns.UI or {}
local UI = ns.UI

local FRAME_NAME = "LegacyNextFrame"
local WIDTH, HEIGHT = 520, 480
local ROW_HEIGHT = 16
local PAD = 12
local FIGURE_WIDTH = 64
local POINTS_WIDTH = 32
local FILTER_GAP = 4

-- A rebuild is a ~900-call sweep, 21 ms on the U1 read. CRITERIA_UPDATE fires for every
-- criterion in the game, not only Legacy ones, so it coalesces over 5 s rather than costing a
-- spike every second while questing. ACHIEVEMENT_EARNED is rare and worth showing promptly.
local EVENT_DELAY = { ACHIEVEMENT_EARNED = 1.0, CRITERIA_UPDATE = 5.0 }
local DEFAULT_DELAY = 1.0

local function G(name)
	return rawget(_G, name)
end

local function fontObject(...)
	for index = 1, select("#", ...) do
		local font = G(select(index, ...))
		if font then
			return font
		end
	end
	return nil
end

local function applyFont(fontString, ...)
	local font = fontObject(...)
	if font then
		fontString:SetFontObject(font)
	end
end

-- CreateFrame with a template, falling back to no template when the template is missing.
local function createFrame(kind, name, parent, template)
	if template then
		local ok, frame = pcall(CreateFrame, kind, name, parent, template)
		if ok and frame then
			return frame, true
		end
	end
	return CreateFrame(kind, name, parent), false
end

--------------------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------------------

UI.filter = nil -- selected group id, nil for All
UI.source = nil -- function() -> Model.BuildView input, set by Core
UI.view = nil -- last view built, for uidump parity checks

function UI.SetDataSource(fn)
	UI.source = fn
end

--------------------------------------------------------------------------------------------
-- Frame construction
--------------------------------------------------------------------------------------------

local function buildHeader(frame, top)
	local line1 = frame:CreateFontString(nil, "OVERLAY")
	applyFont(line1, "GameFontNormalLarge", "GameFontNormal", "ChatFontNormal")
	line1:SetPoint("TOPLEFT", PAD, -top)
	line1:SetPoint("RIGHT", -PAD, 0)
	line1:SetJustifyH("LEFT")
	line1:SetWordWrap(false)

	local line2 = frame:CreateFontString(nil, "OVERLAY")
	applyFont(line2, "GameFontHighlightSmall", "GameFontHighlight", "ChatFontNormal")
	line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -4)
	line2:SetPoint("RIGHT", -PAD, 0)
	line2:SetJustifyH("LEFT")
	line2:SetWordWrap(false)

	frame.headerLines = { line1, line2 }
	return top + 20 + 4 + 14
end

local function buildFilterBar(frame, top)
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT", PAD, -top)
	bar:SetPoint("RIGHT", -PAD, 0)
	bar:SetHeight(24)
	bar.buttons = {}
	frame.filterBar = bar
	return top + 24 + 6
end

local function buildList(frame, top)
	local scroll, templated = createFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PAD, -top)
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 22), PAD)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(WIDTH - PAD * 2 - 22, ROW_HEIGHT)
	scroll:SetScrollChild(child)

	if not templated then
		-- Plain ScrollFrame: wheel scrolling by hand, no scrollbar drawn.
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange() or 0
			local current = self:GetVerticalScroll() or 0
			local target = current - delta * ROW_HEIGHT * 3
			if target < 0 then target = 0 end
			if target > range then target = range end
			self:SetVerticalScroll(target)
		end)
	end

	local status = child:CreateFontString(nil, "OVERLAY")
	applyFont(status, "GameFontDisable", "GameFontNormal", "ChatFontNormal")
	status:SetPoint("TOPLEFT", 0, -4)
	status:SetPoint("RIGHT", 0, 0)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(true)
	status:Hide()

	frame.scroll = scroll
	frame.scrollTemplated = templated
	frame.listChild = child
	frame.status = status
	frame.rows = {}
	frame.dividers = {}
end

local function showTooltip(row)
	local tooltip = G("GameTooltip")
	if not tooltip or not row.data then
		return
	end
	local ok = pcall(tooltip.SetOwner, tooltip, row, "ANCHOR_RIGHT")
	if not ok then
		return
	end
	tooltip:AddLine(row.data.name, 1, 1, 1)
	if row.data.category then
		tooltip:AddLine(row.data.category, 0.7, 0.7, 0.7)
	end
	for _, line in ipairs(row.data.detail or {}) do
		tooltip:AddLine(line, nil, nil, nil, true)
	end
	tooltip:Show()
end

local function hideTooltip()
	local tooltip = G("GameTooltip")
	if tooltip then
		tooltip:Hide()
	end
end

local function acquireRow(frame, index)
	local row = frame.rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, frame.listChild)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("LEFT", 0, 0)
	row:SetPoint("RIGHT", 0, 0)

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)

	local points = row:CreateFontString(nil, "OVERLAY")
	applyFont(points, "GameFontHighlight", "ChatFontNormal")
	points:SetPoint("RIGHT", 0, 0)
	points:SetWidth(POINTS_WIDTH)
	points:SetJustifyH("RIGHT")
	points:SetWordWrap(false)

	local figure = row:CreateFontString(nil, "OVERLAY")
	applyFont(figure, "GameFontHighlight", "ChatFontNormal")
	figure:SetPoint("RIGHT", points, "LEFT", -6, 0)
	figure:SetWidth(FIGURE_WIDTH)
	figure:SetJustifyH("RIGHT")
	figure:SetWordWrap(false)

	local name = row:CreateFontString(nil, "OVERLAY")
	applyFont(name, "GameFontHighlight", "ChatFontNormal")
	name:SetPoint("LEFT", 0, 0)
	name:SetPoint("RIGHT", figure, "LEFT", -6, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	if name.SetMaxLines then
		name:SetMaxLines(1)
	end

	row.name, row.figure, row.points = name, figure, points
	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", hideTooltip)

	frame.rows[index] = row
	return row
end

local function acquireDivider(frame, index)
	local divider = frame.dividers[index]
	if divider then
		return divider
	end

	divider = CreateFrame("Frame", nil, frame.listChild)
	divider:SetHeight(ROW_HEIGHT)
	divider:SetPoint("LEFT", 0, 0)
	divider:SetPoint("RIGHT", 0, 0)

	local left = divider:CreateTexture(nil, "ARTWORK")
	left:SetColorTexture(1, 1, 1, 0.25)
	left:SetHeight(1)
	left:SetPoint("LEFT", 0, 0)

	local label = divider:CreateFontString(nil, "OVERLAY")
	applyFont(label, "GameFontNormalSmall", "GameFontDisable", "ChatFontNormal")
	label:SetPoint("CENTER", 0, 0)
	label:SetJustifyH("CENTER")

	local right = divider:CreateTexture(nil, "ARTWORK")
	right:SetColorTexture(1, 1, 1, 0.25)
	right:SetHeight(1)
	right:SetPoint("RIGHT", 0, 0)

	left:SetPoint("RIGHT", label, "LEFT", -8, 0)
	right:SetPoint("LEFT", label, "RIGHT", 8, 0)

	divider.label = label
	frame.dividers[index] = divider
	return divider
end

local function ensureFrame()
	if UI.frame then
		return UI.frame
	end

	local frame, templated = createFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)

	local top
	if templated then
		if type(frame.TitleText) == "table" then
			frame.TitleText:SetText("LegacyNext")
		end
		-- The template's close button routes through HideUIPanel, which refuses in combat
		-- (UIParentPanelManager.lua:854-861 at the pin). Our frame is not a UI panel; hide it.
		if type(frame.CloseButton) == "table" then
			frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
		end
		top = 32
	else
		local background = frame:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(0, 0, 0, 0.9)

		local title = frame:CreateFontString(nil, "OVERLAY")
		applyFont(title, "GameFontNormal", "ChatFontNormal")
		title:SetPoint("TOP", 0, -8)
		title:SetText("LegacyNext")

		local close, closeTemplated = createFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
		close:SetPoint("TOPRIGHT", -2, -2)
		if not closeTemplated then
			close:SetSize(24, 24)
			local label = close:CreateFontString(nil, "OVERLAY")
			applyFont(label, "GameFontNormal", "ChatFontNormal")
			label:SetAllPoints()
			label:SetText("x")
		end
		close:SetScript("OnClick", function() frame:Hide() end)
		top = 28
	end
	frame.templated = templated

	top = buildHeader(frame, top)
	top = buildFilterBar(frame, top)
	buildList(frame, top)

	-- Escape closes it. UISpecialFrames is iterated as _G[name]:Hide(), which is fine for a
	-- plain frame in or out of combat.
	local special = G("UISpecialFrames")
	if type(special) == "table" then
		special[#special + 1] = FRAME_NAME
		frame.escapeCloses = true
	end

	-- Hide before wiring the handlers and publish UI.frame before either: a frame is shown at
	-- creation, so this Hide() fires OnHide, and the handlers read UI.frame.
	frame:Hide()
	UI.frame = frame

	frame:SetScript("OnShow", function() UI.OnShow() end)
	frame:SetScript("OnHide", function() UI.OnHide() end)
	frame:SetScript("OnEvent", function(_, event) UI.OnEvent(event) end)

	return frame
end

--------------------------------------------------------------------------------------------
-- Rendering a view
--------------------------------------------------------------------------------------------

local function layoutFilters(frame, filters)
	local bar = frame.filterBar
	local barWidth = bar:GetWidth()
	if not barWidth or barWidth <= 0 then
		barWidth = WIDTH - PAD * 2
	end

	local x, y, rowHeight = 0, 0, 22
	local used = 0
	for index, filter in ipairs(filters) do
		local button = bar.buttons[index]
		if not button then
			local templated
			button, templated = createFrame("Button", nil, bar, "UIPanelButtonTemplate")
			button:SetHeight(rowHeight)
			if not templated then
				local bg = button:CreateTexture(nil, "BACKGROUND")
				bg:SetAllPoints()
				bg:SetColorTexture(1, 1, 1, 0.1)
				local label = button:CreateFontString(nil, "OVERLAY")
				applyFont(label, "GameFontNormal", "ChatFontNormal")
				label:SetAllPoints()
				button:SetFontString(label)
				local highlight = button:CreateTexture(nil, "HIGHLIGHT")
				highlight:SetAllPoints()
				highlight:SetColorTexture(1, 1, 1, 0.15)
			end
			button:SetScript("OnClick", function(self)
				UI.SetFilter(self.groupId)
			end)
			bar.buttons[index] = button
		end

		button.groupId = filter.id
		button:SetText(filter.name .. " (" .. tostring(filter.count) .. ")")
		local textWidth = 60
		local fontString = button:GetFontString()
		if fontString and fontString.GetStringWidth then
			textWidth = (fontString:GetStringWidth() or 60) + 20
		end
		button:SetWidth(textWidth)

		if x > 0 and x + textWidth > barWidth then
			x = 0
			y = y + rowHeight + FILTER_GAP
		end
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", x, -y)
		x = x + textWidth + FILTER_GAP
		used = y + rowHeight

		if filter.selected then
			button:LockHighlight()
		else
			button:UnlockHighlight()
		end
		button:Show()
	end

	for index = #filters + 1, #bar.buttons do
		bar.buttons[index]:Hide()
	end

	bar:SetHeight(used > 0 and used or rowHeight)
	frame.scroll:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
end

local function layoutRows(frame, view)
	local child = frame.listChild
	local y = 0
	local rowIndex, dividerIndex = 0, 0

	for _, item in ipairs(view.rows) do
		local widget
		if item.kind == "divider" then
			dividerIndex = dividerIndex + 1
			widget = acquireDivider(frame, dividerIndex)
			widget.label:SetText(item.text)
		else
			rowIndex = rowIndex + 1
			widget = acquireRow(frame, rowIndex)
			widget.data = item
			widget.name:SetText(item.name)
			widget.figure:SetText(item.progressText)
			widget.points:SetText(item.pointsText)
			if item.measurable then
				applyFont(widget.name, "GameFontHighlight", "ChatFontNormal")
			else
				applyFont(widget.name, "GameFontDisable", "GameFontHighlight", "ChatFontNormal")
			end
		end
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", 0, -y)
		widget:SetPoint("RIGHT", 0, 0)
		widget:Show()
		y = y + ROW_HEIGHT
	end

	for index = rowIndex + 1, #frame.rows do
		frame.rows[index]:Hide()
		frame.rows[index].data = nil
	end
	for index = dividerIndex + 1, #frame.dividers do
		frame.dividers[index]:Hide()
	end

	if view.state ~= "ok" then
		frame.status:SetText(view.message or view.state)
		frame.status:Show()
		y = y + 40
	elseif view.footnote then
		frame.status:SetText(view.footnote)
		frame.status:Show()
		y = y + 40
	else
		frame.status:Hide()
	end

	child:SetHeight(math.max(y, ROW_HEIGHT))
	child:SetWidth(frame.scroll:GetWidth() or (WIDTH - PAD * 2 - 22))
end

function UI.Render(view)
	local frame = ensureFrame()
	UI.view = view

	frame.headerLines[1]:SetText(view.header.lines[1] or "")
	frame.headerLines[2]:SetText(view.header.lines[2] or "")

	layoutFilters(frame, view.filters or {})
	layoutRows(frame, view)
end

-- Reads through the data source and redraws. Never called from a draw path. The read is
-- pcall'd as a whole: Api guards each client call, but an unexpected shape can still throw in
-- the code around them, and a throw here would repeat on every open until the client stops
-- reporting errors at 100. The error becomes the view's error state instead.
function UI.Refresh()
	if not UI.source or not ns.Model then
		return
	end
	local ok, view = pcall(function()
		local input = UI.source()
		input.filter = UI.filter
		return ns.Model.BuildView(input)
	end)
	if ok then
		-- BuildView falls back to All when the filtered group has gone; follow it, so the
		-- next read does not ask for the missing group again.
		UI.filter = view.filter
	else
		view = ns.Model.BuildView({ challengesReason = tostring(view) })
	end
	UI.Render(view)
	return view
end

function UI.SetFilter(groupId)
	UI.filter = groupId
	if UI.frame and UI.frame:IsShown() then
		UI.Refresh()
	end
end

--------------------------------------------------------------------------------------------
-- Show, hide, events, throttle
--------------------------------------------------------------------------------------------

local REFRESH_EVENTS = { "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE" }

local function inCombat()
	local check = G("InCombatLockdown")
	return type(check) == "function" and check() and true or false
end

-- The frame is not protected, but a ~900-call sweep is not something to run mid-fight, so
-- any read that lands in combat waits for PLAYER_REGEN_ENABLED.
local function deferForCombat()
	UI.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	UI.deferredForCombat = true
	UI.refreshPending = true
end

-- Coalesces a burst of events into one refresh `delay` seconds out. A pending refresh is kept
-- unless the new request wants it sooner; then the new timer supersedes it, and the old one
-- sees a stale token and does nothing.
function UI.RequestRefresh(delay)
	delay = delay or DEFAULT_DELAY
	if not UI.frame or not UI.frame:IsShown() or UI.deferredForCombat then
		return
	end
	if UI.refreshPending and UI.pendingDelay <= delay then
		return
	end
	UI.refreshPending = true
	UI.pendingDelay = delay
	UI.refreshToken = (UI.refreshToken or 0) + 1
	local token = UI.refreshToken

	local function fire()
		if token ~= UI.refreshToken then
			return
		end
		if not UI.frame or not UI.frame:IsShown() then
			UI.refreshPending = false
			return
		end
		if inCombat() then
			deferForCombat()
			return
		end
		UI.refreshPending = false
		UI.Refresh()
	end

	local timer = G("C_Timer")
	if type(timer) == "table" and type(timer.After) == "function" then
		timer.After(delay, fire)
	else
		fire()
	end
end

function UI.OnEvent(event)
	if event == "PLAYER_REGEN_ENABLED" then
		UI.frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if UI.deferredForCombat then
			UI.deferredForCombat = false
			UI.refreshPending = false
			UI.Refresh()
		end
		return
	end
	UI.RequestRefresh(EVENT_DELAY[event])
end

-- Shown on a first open that lands in combat, until the read can run.
local WAITING_VIEW = {
	header = { lines = { "", "" }, state = "ok" },
	filters = {},
	rows = {},
	state = "waiting",
	message = "Reading your challenges when combat ends",
}

function UI.OnShow()
	for _, event in ipairs(REFRESH_EVENTS) do
		pcall(UI.frame.RegisterEvent, UI.frame, event)
	end
	if inCombat() then
		-- A reopened frame keeps its last view until then; a first open says why it is blank.
		deferForCombat()
		if not UI.view then
			UI.Render(WAITING_VIEW)
		end
		return
	end
	UI.Refresh()
end

function UI.OnHide()
	for _, event in ipairs(REFRESH_EVENTS) do
		pcall(UI.frame.UnregisterEvent, UI.frame, event)
	end
	pcall(UI.frame.UnregisterEvent, UI.frame, "PLAYER_REGEN_ENABLED")
	UI.refreshToken = (UI.refreshToken or 0) + 1 -- a timer still in flight does nothing
	UI.refreshPending = false
	UI.deferredForCombat = false
	hideTooltip()
end

function UI.Show()
	ensureFrame():Show()
end

function UI.Hide()
	if UI.frame then
		UI.frame:Hide()
	end
end

function UI.Toggle()
	local frame = ensureFrame()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

-- What the frame decided about its environment, for /lgn probe-style reporting.
function UI.Describe()
	local frame = UI.frame
	if not frame then
		return { created = false }
	end
	return {
		created = true,
		frameTemplate = frame.templated and "BasicFrameTemplateWithInset" or "plain",
		scrollTemplate = frame.scrollTemplated and "UIPanelScrollFrameTemplate" or "plain",
		escapeCloses = frame.escapeCloses and true or false,
		rows = #frame.rows,
		shown = frame:IsShown() and true or false,
	}
end
