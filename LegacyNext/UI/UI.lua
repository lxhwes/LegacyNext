local _, ns = ...

-- The v0 frame. Reads from Model, never from Api: Core hands in a data source that returns
-- the Model.BuildView input, and everything drawn here comes out of that view. v0 is a
-- standalone frame; we do not hook Blizzard frames. The tab, filter, position and size are
-- saved per character through Store.
--
-- Templates and font objects are cited in docs/ui-templates.md at pin 70ef1b2. Every one is
-- feature-detected here anyway: a missing template falls back to a plain frame rather than an
-- error, because an error at load is a blank window Alex cannot debug interactively.
ns.UI = ns.UI or {}
local UI = ns.UI

local FRAME_NAME = "LegacyNextFrame"
-- The designed size, and the size a first open or an unusable save gets.
local WIDTH, HEIGHT = 520, 480
-- The smallest size the layout survives. At 400 wide a name keeps 228 px after the icon and the
-- two value columns, which at an estimated 7 px a character fits the longest name in the
-- uidump goldens (29 characters). The header lines clip with an ellipsis (U2), the two tabs
-- need under 200 px and the filter bar wraps. At 360 tall, with three rows of filters, about
-- nine list rows still show.
local MIN_WIDTH, MIN_HEIGHT = 400, 360
local ROW_HEIGHT = 16
local PAD = 12
local FIGURE_WIDTH = 64
local POINTS_WIDTH = 32
local FILTER_GAP = 4
local ICON_SIZE = 14
local ICON_GAP = 4
-- The row kinds whose view rows carry an icon.
local ICON_KINDS = { challenge = true, tradeskill = true }
-- Width of the scroll bar column right of the list.
local SCROLLBAR_WIDTH = 22

-- The resize grip: Blizzard's template (SharedUIPanelTemplates.xml:1642 at 9a789c0, 16 px),
-- or a button drawn with the same chat size-grabber art (:1650-1652) when it is missing.
local GRIP_TEMPLATE = "PanelResizeButtonTemplate"
local GRIP_SIZE = 16
local GRIP_ART = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"
-- The list's bottom inset with a grip. The scroll bar's down button hangs 16 px below the bar
-- (SecureScrollTemplates.xml:18-21, :48-49), so at the usual PAD it would sit under the grip.
local GRIP_LIST_BOTTOM = GRIP_SIZE + 2
-- OnSizeChanged fires on every frame of a drag, so the relayout runs at most once in this many
-- seconds, and at once on release.
local RELAYOUT_DELAY = 0.1

-- A rebuild is a ~900-call sweep, 21 ms on the U1 read. CRITERIA_UPDATE fires for every
-- criterion in the game, not only Legacy ones, so it coalesces over 5 s rather than costing a
-- spike every second while questing. ACHIEVEMENT_EARNED is rare and worth showing promptly.
local EVENT_DELAY = { ACHIEVEMENT_EARNED = 1.0, CRITERIA_UPDATE = 5.0 }
local DEFAULT_DELAY = 1.0

local function G(name)
	return rawget(_G, name)
end

-- A finite number that is not a secret value: comparing or formatting a secret throws.
local function plainNumber(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	local isSecret = G("issecretvalue")
	return not (type(isSecret) == "function" and isSecret(value))
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

-- A texture file id or path, as the view hands them over.
local function usableIcon(icon)
	return type(icon) == "number" or (type(icon) == "string" and icon ~= "")
end

-- The client's colour for a class token, as r, g, b, or nil. RAID_CLASS_COLORS first
-- (ClassColors.lua:1-25 at 966519c, filled from C_ClassColor), since class-colour addons
-- recolour that table; then C_ClassColor.GetClassColor (ClassColorDocumentation.lua:11,
-- MayReturnNothing).
local function classColor(token)
	if type(token) ~= "string" or token == "" then
		return nil
	end
	local colors = G("RAID_CLASS_COLORS")
	local color = type(colors) == "table" and colors[token] or nil
	if type(color) ~= "table" then
		local api = G("C_ClassColor")
		if type(api) == "table" and type(api.GetClassColor) == "function" then
			local ok, result = pcall(api.GetClassColor, token)
			color = ok and result or nil
		end
	end
	if type(color) == "table" and plainNumber(color.r) and plainNumber(color.g) and plainNumber(color.b) then
		return color.r, color.g, color.b
	end
	return nil
end

local function colorByte(value)
	return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

-- The name wrapped in a colour escape, the form Blizzard's RGBToColorCode builds
-- (ColorUtil.lua:90-92). Nothing stays set on the FontString, so a pooled row drawn next
-- without a class is back in its font's colour. Returns the text and whether it was coloured.
local function classColored(text, token)
	local r, g, b = classColor(token)
	if not r then
		return text, false
	end
	return ("|cff%02x%02x%02x%s|r"):format(colorByte(r), colorByte(g), colorByte(b), text), true
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

-- A text button: UIPanelButtonTemplate, or a flat one drawn by hand if the template is gone.
-- Returns the button and whether the template was used.
local function createButton(parent, height)
	local button, templated = createFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetHeight(height)
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
	return button, templated
end

--------------------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------------------

UI.tab = "nextup"
UI.filter = nil -- selected Next Up group id, nil for All; kept across a trip to the roster
UI.source = nil -- function() -> Model.BuildView / BuildRosterView input, set by Core
UI.view = nil -- last view built, for uidump parity checks
UI.nextUpFilters = nil -- the last Next Up view's filters, drawn while a read waits for combat

local TABS = {
	{ id = "nextup", label = "Next Up" },
	{ id = "roster", label = "Roster" },
}
local TAB_WIDTH = 80
local BUTTON_TAB_HEIGHT = 22
-- Blizzard's top tab: SharedUIPanelTemplates.xml:1006 at 966519c, 32 tall from :933, its art
-- along the bottom. Forever's own FriendsFrame builds its tabs from the same family.
local TAB_TEMPLATE = "PanelTopTabButtonTemplate"
local TAB_TEMPLATE_HEIGHT = 32

function UI.SetDataSource(fn)
	UI.source = fn
end

local function knownTab(tab)
	for _, entry in ipairs(TABS) do
		if entry.id == tab then
			return true
		end
	end
	return false
end

-- Window state is saved per character through Store. Without a Store the window still works;
-- it just opens as it did.
local function store()
	local Store = ns.Store
	if type(Store) == "table" and type(Store.GetUIState) == "function"
		and type(Store.PutUIState) == "function" then
		return Store
	end
	return nil
end

local function saveState(name, value)
	local Store = store()
	if Store then
		Store.PutUIState(name, value)
	end
end

-- UIParent's width and height, or nil when either cannot be read.
local function screenSize()
	local parent = G("UIParent")
	local width = parent and parent:GetWidth()
	local height = parent and parent:GetHeight()
	if plainNumber(width) and plainNumber(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

-- The frame's live width, or the designed one while it cannot be read.
local function frameWidth(frame)
	local width = frame:GetWidth()
	if plainNumber(width) and width > 0 then
		return width
	end
	return WIDTH
end

-- Anchors the frame at a saved top-left corner, clamped onto the screen at the frame's size so
-- a smaller screen or a larger UI scale since the save cannot strand it. Centred when the save
-- or the screen size cannot be read.
local function placeFrame(frame, point, width, height)
	frame:ClearAllPoints()
	local screenWidth, screenHeight = screenSize()
	if type(point) ~= "table" or not plainNumber(point.left) or not plainNumber(point.top)
		or not screenWidth then
		frame:SetPoint("CENTER")
		return
	end
	local left = math.max(0, math.min(point.left, screenWidth - width))
	local top = math.min(screenHeight, math.max(point.top, height))
	frame:SetPoint("TOPLEFT", G("UIParent"), "BOTTOMLEFT", left, top)
end

-- A saved size, held between the minimum and the screen. The designed size when the save is
-- unusable; the minimum alone when the screen cannot be read.
local function restoredSize(size)
	if type(size) ~= "table" or not plainNumber(size.width) or not plainNumber(size.height) then
		return WIDTH, HEIGHT
	end
	local width, height = size.width, size.height
	local screenWidth, screenHeight = screenSize()
	if screenWidth then
		width, height = math.min(width, screenWidth), math.min(height, screenHeight)
	end
	return math.max(MIN_WIDTH, width), math.max(MIN_HEIGHT, height)
end

local function restoreState(frame)
	local Store = store()
	local saved = Store and Store.GetUIState() or {}
	if knownTab(saved.tab) then
		UI.tab = saved.tab
	end
	-- A category id; one that has gone since is BuildView's to drop, and it falls back to All.
	if type(saved.filter) == "number" or type(saved.filter) == "string" then
		UI.filter = saved.filter
	end
	local width, height = restoredSize(saved.size)
	frame:SetSize(width, height)
	placeFrame(frame, saved.point, width, height)
end

-- GetLeft and GetTop measure from the screen's bottom-left, in UIParent's scale since the
-- frame is its child at scale 1, which is the space placeFrame anchors in.
local function savePosition(frame)
	local left, top = frame:GetLeft(), frame:GetTop()
	if plainNumber(left) and plainNumber(top) then
		saveState("point", { left = left, top = top })
	end
end

local function onDragStop(frame)
	frame:StopMovingOrSizing()
	savePosition(frame)
end

--------------------------------------------------------------------------------------------
-- Resizing
--------------------------------------------------------------------------------------------

-- Lays the list out at the frame's live width; defined with the rendering below.
local relayout

-- Sets the resize bounds, minimum to screen, and returns the method that took them: the
-- documented SetResizeBounds (SimpleFrameAPIDocumentation.lua:1445 at 9a789c0), else the
-- older SetMinResize / SetMaxResize pair, which the pin does not document. Nil when neither
-- exists or the call throws, and the window then keeps a fixed size.
local function applyResizeBounds(frame)
	local maxWidth, maxHeight = screenSize()
	if maxWidth then
		maxWidth, maxHeight = math.max(maxWidth, MIN_WIDTH), math.max(maxHeight, MIN_HEIGHT)
	end
	if type(frame.SetResizeBounds) == "function" then
		if pcall(frame.SetResizeBounds, frame, MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight) then
			return "SetResizeBounds"
		end
		return nil
	end
	if type(frame.SetMinResize) == "function" then
		if not pcall(frame.SetMinResize, frame, MIN_WIDTH, MIN_HEIGHT) then
			return nil
		end
		if maxWidth and type(frame.SetMaxResize) == "function" then
			pcall(frame.SetMaxResize, frame, maxWidth, maxHeight)
		end
		return "SetMinResize"
	end
	return nil
end

-- Makes the frame resizable when the client can bound it. Returns the bounds method, or nil.
local function enableResize(frame)
	if type(frame.SetResizable) ~= "function" or type(frame.StartSizing) ~= "function"
		or type(frame.StopMovingOrSizing) ~= "function" then
		return nil
	end
	local api = applyResizeBounds(frame)
	if api and pcall(frame.SetResizable, frame, true) then
		return api
	end
	return nil
end

local function saveSize(frame)
	local width, height = frame:GetWidth(), frame:GetHeight()
	if plainNumber(width) and plainNumber(height) then
		saveState("size", { width = width, height = height })
	end
end

-- From the bottom-right corner and from the cursor, as both of Blizzard's grips do
-- (SharedUIPanelTemplates.lua:1694-1695, LootHistory.lua:433-434). StartSizing is flagged
-- protected, as StartMoving is, and our frame is not (U2), so this works in combat.
local function startSizing(frame, button)
	if button ~= "LeftButton" or frame.sizing then
		return
	end
	frame.sizing = pcall(frame.StartSizing, frame, "BOTTOMRIGHT", true) and true or false
end

-- The corner is saved with the size: a centred window has none saved, and without one the
-- restore would centre it at its new size somewhere else.
local function stopSizing(frame)
	if not frame.sizing then
		return
	end
	frame.sizing = false
	frame:StopMovingOrSizing()
	relayout(frame)
	saveSize(frame)
	savePosition(frame)
end

-- The template's own mouse scripts (:1676-1719) are replaced, as LootHistory replaces its
-- grip's, so both grips size the same way; it keeps its art and its resize cursor.
local function buildGrip(frame)
	local grip, templated = createFrame("Button", nil, frame, GRIP_TEMPLATE)
	if not templated then
		grip:SetSize(GRIP_SIZE, GRIP_SIZE)
		grip:SetNormalTexture(GRIP_ART .. "Up")
		grip:SetHighlightTexture(GRIP_ART .. "Highlight")
		grip:SetPushedTexture(GRIP_ART .. "Down")
	end
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:EnableMouse(true)
	grip:SetScript("OnMouseDown", function(_, button) startSizing(frame, button) end)
	grip:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			stopSizing(frame)
		end
	end)
	frame.grip = grip
	frame.gripStyle = templated and GRIP_TEMPLATE or "plain"
end

-- Coalesces a drag's size changes into one relayout per RELAYOUT_DELAY.
local function requestRelayout(frame)
	if frame.relayoutPending then
		return
	end
	local timer = G("C_Timer")
	if type(timer) == "table" and type(timer.After) == "function" then
		frame.relayoutPending = true
		timer.After(RELAYOUT_DELAY, function() relayout(frame) end)
	else
		relayout(frame)
	end
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

	-- The next reward's icon, drawn before line 2 when the view has one.
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -3)
	icon:Hide()

	local line2 = frame:CreateFontString(nil, "OVERLAY")
	applyFont(line2, "GameFontHighlightSmall", "GameFontHighlight", "ChatFontNormal")
	line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -4)
	line2:SetPoint("RIGHT", -PAD, 0)
	line2:SetJustifyH("LEFT")
	line2:SetWordWrap(false)

	frame.headerLines = { line1, line2 }
	frame.headerIcon = icon
	return top + 20 + 4 + 14
end

local function drawHeader(frame, header)
	local line1, line2, icon = frame.headerLines[1], frame.headerLines[2], frame.headerIcon
	line1:SetText(header.lines[1] or "")
	line2:SetText(header.lines[2] or "")
	line2:ClearAllPoints()
	if usableIcon(header.icon) then
		icon:SetTexture(header.icon)
		icon:Show()
		line2:SetPoint("LEFT", icon, "RIGHT", ICON_GAP, 0)
	else
		icon:SetTexture(nil)
		icon:Hide()
		line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -4)
	end
	line2:SetPoint("RIGHT", -PAD, 0)
end

-- The top tab when the template and its select helpers (SharedUIPanelTemplates.lua:616, :598)
-- are both there. Otherwise the panel button, whose selected state is only white text on the
-- same red art, so it also gets a gold underline. tabStyle and underline are always set, so
-- markTab never reads a missing field.
local function createTab(parent)
	if type(G("PanelTemplates_SelectTab")) == "function"
		and type(G("PanelTemplates_DeselectTab")) == "function" then
		local ok, button = pcall(CreateFrame, "Button", nil, parent, TAB_TEMPLATE)
		if ok and button then
			button.tabStyle = TAB_TEMPLATE
			button.underline = false
			return button
		end
	end
	local button, templated = createButton(parent, BUTTON_TAB_HEIGHT)
	button:SetWidth(TAB_WIDTH)
	button.tabStyle = templated and "UIPanelButtonTemplate" or "plain"
	local underline = button:CreateTexture(nil, "OVERLAY")
	underline:SetColorTexture(1, 0.82, 0, 1) -- gold, as GameFontNormal's text
	underline:SetHeight(2)
	underline:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 2, -1)
	underline:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -2, -1)
	underline:Hide()
	button.underline = underline
	return button
end

-- SelectTab also disables the tab, which is how Blizzard's selected tabs look: raised art and
-- white text, not greyed. A helper that throws falls through to the button's marking.
local function markTab(button, selected)
	if button.tabStyle == TAB_TEMPLATE then
		local helper = G(selected and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab")
		if type(helper) == "function" and pcall(helper, button) then
			return
		end
	end
	if selected then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
	if button.underline then
		if selected then
			button.underline:Show()
		else
			button.underline:Hide()
		end
	end
end

local function buildTabs(frame, top)
	frame.tabs = {}
	-- The template resizes itself on show from its parent's minTabWidth (:262-264).
	frame.minTabWidth = TAB_WIDTH
	local height = BUTTON_TAB_HEIGHT
	for index, tab in ipairs(TABS) do
		local button = createTab(frame)
		-- A top tab's width follows its text, so each hangs off the one before, as
		-- PanelTemplates_AnchorTabs does (:545-551).
		if index == 1 then
			button:SetPoint("TOPLEFT", PAD, -top)
		else
			button:SetPoint("TOPLEFT", frame.tabs[index - 1], "TOPRIGHT", FILTER_GAP, 0)
		end
		button.tab = tab.id
		button:SetText(tab.label)
		if button.tabStyle == TAB_TEMPLATE then
			height = TAB_TEMPLATE_HEIGHT
			local resize = G("PanelTemplates_TabResize")
			if type(resize) == "function" then
				pcall(resize, button, 0, nil, TAB_WIDTH)
			end
		end
		button:SetScript("OnClick", function(self)
			UI.SetTab(self.tab)
		end)
		frame.tabs[index] = button
	end
	return top + height + 6
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

local function buildList(frame, top, bottom)
	local scroll, templated = createFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PAD, -top)
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + SCROLLBAR_WIDTH), bottom)

	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(frameWidth(frame) - PAD * 2 - SCROLLBAR_WIDTH, ROW_HEIGHT)
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

	-- Marks the current character once its name is in class colour rather than gold.
	local tint = row:CreateTexture(nil, "BACKGROUND")
	tint:SetAllPoints()
	tint:SetColorTexture(1, 0.82, 0, 0.12)
	tint:Hide()

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("LEFT", 0, 0)
	icon:Hide()

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
	row.icon, row.tint = icon, tint
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
	-- Every field read later is set here, false rather than nil, before any handler can run.
	frame.sizing = false
	frame.relayoutPending = false
	frame.laidOutWidth = false
	frame.rowsHeight = 0
	frame.listNote = false
	frame.grip = false
	frame.gripStyle = "none"
	-- First build: the tab, filter, size and position this character left the window with.
	restoreState(frame)
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", onDragStop)
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

	frame.resizeApi = enableResize(frame) or false

	top = buildHeader(frame, top)
	top = buildTabs(frame, top)
	top = buildFilterBar(frame, top)
	buildList(frame, top, frame.resizeApi and GRIP_LIST_BOTTOM or PAD)
	if frame.resizeApi then
		buildGrip(frame)
	end

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
	-- The script Blizzard's grip hooks on its target (SharedUIPanelTemplates.lua:1627-1628).
	frame:SetScript("OnSizeChanged", function() requestRelayout(frame) end)

	return frame
end

--------------------------------------------------------------------------------------------
-- Rendering a view
--------------------------------------------------------------------------------------------

local function layoutFilters(frame, filters)
	local bar = frame.filterBar
	local barWidth = bar:GetWidth()
	if not plainNumber(barWidth) or barWidth <= 0 then
		barWidth = frameWidth(frame) - PAD * 2
	end

	local x, y, rowHeight = 0, 0, 22
	local used = 0
	for index, filter in ipairs(filters) do
		local button = bar.buttons[index]
		if not button then
			button = createButton(bar, rowHeight)
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

	-- The roster has no filters; collapse the bar rather than leave a blank band.
	bar:SetHeight(used > 0 and used or 1)
	frame.scroll:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -6)
end

local HEADING_FONTS = { "GameFontNormalSmall", "GameFontNormal", "ChatFontNormal" }
local VALUE_FONTS = { "GameFontHighlight", "ChatFontNormal" }
local CURRENT_FONTS = { "GameFontNormal", "GameFontHighlight", "ChatFontNormal" }
local DIM_FONTS = { "GameFontDisable", "GameFontHighlight", "ChatFontNormal" }

-- Rows are pooled across tabs, so every draw sets all three fonts: a pooled heading row must
-- not leave its gold small font on the challenge row that reuses it.
local function styleRow(widget, item)
	local nameFonts, valueFonts = VALUE_FONTS, VALUE_FONTS
	if item.kind == "columns" then
		nameFonts, valueFonts = HEADING_FONTS, HEADING_FONTS
	elseif item.current then
		nameFonts = CURRENT_FONTS
	elseif not item.measurable then
		nameFonts = DIM_FONTS
	end
	applyFont(widget.name, unpack(nameFonts))
	applyFont(widget.figure, unpack(valueFonts))
	applyFont(widget.points, unpack(valueFonts))
end

-- The name, its icon and the current-character tint. Each is set or cleared on every draw, so
-- a pooled row never keeps another row's. `iconSlot` indents every row of an icon kind, with
-- or without an icon of its own, so their names line up.
local function drawName(widget, item, iconSlot)
	local text, colored = item.name, false
	if item.kind == "character" and type(item.name) == "string" then
		text, colored = classColored(item.name, item.classToken)
	end
	widget.name:SetText(text)
	if colored and item.current then
		widget.tint:Show()
	else
		widget.tint:Hide()
	end

	local indent = 0
	if iconSlot and ICON_KINDS[item.kind] then
		indent = ICON_SIZE + ICON_GAP
	end
	if indent > 0 and usableIcon(item.icon) then
		widget.icon:SetTexture(item.icon)
		widget.icon:Show()
	else
		widget.icon:SetTexture(nil)
		widget.icon:Hide()
	end
	widget.name:ClearAllPoints()
	widget.name:SetPoint("LEFT", indent, 0)
	widget.name:SetPoint("RIGHT", widget.figure, "LEFT", -6, 0)
end

-- The scroll frame's width, or what the frame's width leaves for it while its rect is still
-- unresolved (0).
local function listWidth(frame)
	local width = frame.scroll:GetWidth()
	if not plainNumber(width) or width <= 0 then
		return frameWidth(frame) - PAD * 2 - SCROLLBAR_WIDTH
	end
	return width
end

-- The note's wrapped height, measured the way Blizzard's ScrollingFontMixin sizes its text
-- (SetWidth, then GetStringHeight: ScrollTemplates.lua:321-325 at 966519c). 28 px a line stays
-- the floor, and the whole answer when the client cannot measure. The doc marks the height
-- SecretWhenAnchoringSecret (SimpleFontStringAPIDocumentation.lua:325); ours never is, but
-- comparing a secret throws, so it is checked.
local function noteHeight(status, note)
	local lines = 1
	for _ in note:gmatch("\n") do
		lines = lines + 1
	end
	local estimate = 28 * lines
	if type(status.GetStringHeight) ~= "function" then
		return estimate
	end
	local ok, height = pcall(status.GetStringHeight, status)
	local isSecret = G("issecretvalue")
	if ok and type(isSecret) == "function" and isSecret(height) then
		return estimate
	end
	if ok and type(height) == "number" and height > estimate then
		return height
	end
	return estimate
end

-- Sizes the scroll child, and the note under the rows, to the list's live width. A set width on
-- the note rather than a RIGHT anchor, so the wrap is known before it is measured.
local function sizeList(frame)
	local width = listWidth(frame)
	local y = frame.rowsHeight
	if frame.listNote then
		frame.status:SetWidth(width)
		y = y + 12 + noteHeight(frame.status, frame.listNote)
	end
	frame.listChild:SetHeight(math.max(y, ROW_HEIGHT))
	frame.listChild:SetWidth(width)
	frame.laidOutWidth = width
end

local function layoutRows(frame, view)
	local y = 0
	local rowIndex, dividerIndex = 0, 0

	-- No icon on any row, no slot: names stay where they were before rows had icons.
	local iconSlot = false
	for _, item in ipairs(view.rows) do
		iconSlot = iconSlot or (ICON_KINDS[item.kind] and usableIcon(item.icon)) or false
	end

	for _, item in ipairs(view.rows) do
		local widget
		if item.kind == "divider" then
			dividerIndex = dividerIndex + 1
			widget = acquireDivider(frame, dividerIndex)
			widget.label:SetText(item.text)
		else
			rowIndex = rowIndex + 1
			widget = acquireRow(frame, rowIndex)
			-- A heading has no tooltip and takes no mouse, so it does not highlight on hover.
			local heading = item.kind == "columns"
			widget.data = not heading and item or nil
			widget:EnableMouse(not heading)
			drawName(widget, item, iconSlot)
			widget.figure:SetText(item.progressText)
			widget.points:SetText(item.pointsText)
			styleRow(widget, item)
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

	-- A state message, a footnote, or both. Anchored below the last row on every draw, since a
	-- footnote under a list anchored at the top prints over the first two rows.
	local note = view.footnote
	if view.state ~= "ok" then
		note = tostring(view.message or view.state) .. (note and ("\n" .. note) or "")
	end
	local status = frame.status
	if note then
		status:ClearAllPoints()
		status:SetPoint("TOPLEFT", 0, -(y + 4))
		status:SetText(note)
		status:Show()
	else
		status:Hide()
	end

	frame.rowsHeight = y
	frame.listNote = note or false
	sizeList(frame)
end

function UI.Render(view)
	local frame = ensureFrame()
	UI.view = view

	drawHeader(frame, view.header)

	for _, button in ipairs(frame.tabs) do
		markTab(button, button.tab == UI.tab)
	end

	layoutFilters(frame, view.filters or {})
	layoutRows(frame, view)
end

-- After a resize: the filter bar's wrap and the list's width follow the live size. Rows are
-- anchored to both sides of the scroll child, so they follow it; nothing is read or redrawn.
-- A change of height alone needs nothing, since the scroll frame is anchored top and bottom.
relayout = function(frame)
	frame.relayoutPending = false
	local view = UI.view
	if not view or listWidth(frame) == frame.laidOutWidth then
		return
	end
	layoutFilters(frame, view.filters or {})
	sizeList(frame)
end

-- Reads through the data source and redraws. Never called from a draw path. The read is
-- pcall'd as a whole: Api guards each client call, but an unexpected shape can still throw in
-- the code around them, and a throw here would repeat on every open until the client stops
-- reporting errors at 100. The error becomes the view's error state instead.
function UI.Refresh()
	if not UI.source or not ns.Model then
		return
	end
	local roster = UI.tab == "roster"
	local ok, view = pcall(function()
		local input = UI.source()
		if roster then
			return ns.Model.BuildRosterView(input)
		end
		input.filter = UI.filter
		return ns.Model.BuildView(input)
	end)
	if ok then
		-- BuildView falls back to All when the filtered group has gone; follow it, so the
		-- next read does not ask for the missing group again.
		if not roster then
			UI.filter = view.filter
			UI.nextUpFilters = view.filters
		end
	elseif roster then
		view = ns.Model.BuildRosterView({ error = tostring(view) })
	else
		view = ns.Model.BuildView({ challengesReason = tostring(view) })
	end
	UI.Render(view)
	return view
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

-- Core took a snapshot after a level, skill or trait change. Those events are Core's, not the
-- frame's, and the Roster tab is the view they change.
function UI.OnSnapshot()
	if UI.tab == "roster" then
		UI.RequestRefresh()
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

-- Shown on a first open or a switch that lands in combat, until the read can run. The header
-- is the same on both tabs and already read, so it stays. So does Next Up's filter bar, marked
-- with the choice just made, so another filter can still be picked.
local function waitingView()
	local filters = {}
	if UI.tab == "nextup" then
		for index, filter in ipairs(UI.nextUpFilters or {}) do
			filters[index] = { id = filter.id, name = filter.name, count = filter.count,
				selected = filter.id == UI.filter }
		end
	end
	return {
		header = UI.view and UI.view.header or { lines = { "", "" }, state = "ok" },
		filters = filters,
		rows = {},
		state = "waiting",
		message = UI.tab == "roster" and "Reading the roster when combat ends"
			or "Reading your challenges when combat ends",
	}
end

-- A tab or filter switch reads at once, or after combat as a first open does. The old view
-- stays off screen meanwhile: it would sit under the new tab's highlight.
local function refreshOrDefer()
	if not UI.frame or not UI.frame:IsShown() then
		return
	end
	if UI.deferredForCombat or inCombat() then
		if not UI.deferredForCombat then
			deferForCombat()
		end
		UI.Render(waitingView())
		return
	end
	UI.Refresh()
end

function UI.SetTab(tab)
	if not knownTab(tab) or tab == UI.tab then
		return
	end
	UI.tab = tab
	saveState("tab", tab)
	refreshOrDefer()
end

function UI.SetFilter(groupId)
	UI.filter = groupId
	saveState("filter", groupId)
	refreshOrDefer()
end

function UI.OnShow()
	for _, event in ipairs(REFRESH_EVENTS) do
		pcall(UI.frame.RegisterEvent, UI.frame, event)
	end
	if inCombat() then
		-- A reopened frame keeps its last view until then; a first open says why it is blank.
		deferForCombat()
		if not UI.view then
			UI.Render(waitingView())
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
	-- Escape mid-drag: end the sizing and keep the size it reached.
	stopSizing(UI.frame)
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
	local width, height = frame:GetWidth(), frame:GetHeight()
	local resizable
	if type(frame.IsResizable) == "function" then
		local ok, value = pcall(frame.IsResizable, frame)
		if ok and type(value) == "boolean" then
			resizable = value
		end
	end
	return {
		created = true,
		-- The live size, and how resizing was set up: the bounds method or "none", the grip's
		-- template or "plain", and what the client says IsResizable is.
		width = plainNumber(width) and math.floor(width + 0.5) or nil,
		height = plainNumber(height) and math.floor(height + 0.5) or nil,
		resize = frame.resizeApi or "none",
		grip = frame.gripStyle,
		resizable = resizable,
		frameTemplate = frame.templated and "BasicFrameTemplateWithInset" or "plain",
		scrollTemplate = frame.scrollTemplated and "UIPanelScrollFrameTemplate" or "plain",
		tabTemplate = frame.tabs[1] and frame.tabs[1].tabStyle or "none",
		escapeCloses = frame.escapeCloses and true or false,
		tab = UI.tab,
		rows = #frame.rows,
		shown = frame:IsShown() and true or false,
	}
end
