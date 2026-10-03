local _, ns = ...

-- A draggable button on the minimap's edge, hand-rolled rather than LibDBIcon so v0 keeps no
-- external libs (Alex, 2026-10-02). Left click toggles the window, right click opens the
-- Settings category, and the tooltip is Model.BuildSummary drawn line by line. Its angle and
-- the hide and lock choices are account-wide, through Store.
--
-- Parented to Minimap, so Edit Mode's scale on MinimapContainer (Minimap.lua:374-382 at
-- 9a789c0) carries it along. The minimap is round on Forever (Camelot/Skin.lua:34), and no
-- GetMinimapShape exists at the pin, so the edge is a circle. Nothing in Blizzard_Minimap moves
-- or hides third-party children. Seen in game is U10.
ns.MinimapButton = ns.MinimapButton or {}
local Button = ns.MinimapButton

local BUTTON_NAME = "LegacyNextMinimapButton"
local SIZE = 31
Button.DEFAULT_ANGLE = 225 -- lower left, clear of the clock and the addon dropdown at the top
-- Past the minimap's radius, so the ring sits on its rim.
Button.EDGE = 5
-- A summary read is the window's ~900-call sweep, so hovering reuses one for this long.
Button.SUMMARY_TTL = 30
Button.HINT = "Click to open or close. Right-click for settings. Drag to move."
-- The dropdown entry toggles on any click (Core.lua, LegacyNext_OnAddonCompartmentClick).
Button.COMPARTMENT_HINT = "Click to open or close."
Button.COMBAT_LINE = "Summary after combat"

-- Textures the pin shows in use: the ring (Blizzard_FrameXML/ItemDisplay.xml:84), the
-- minimap's own button highlight (Blizzard_Minimap/Mainline/Minimap.xml:411), and the round
-- portrait mask (Blizzard_SharedXML/Shared/FrameTemplate/RingedFrameTemplate.xml:51).
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ICON = "Interface\\AddOns\\LegacyNext\\Media\\icon"

Button.button = nil
Button.summarySource = nil -- function() -> Model.BuildSummary output, set by Core
local cached, cachedAt = nil, nil

local function G(name)
	return rawget(_G, name)
end

-- A finite number that is not a secret value: comparing or formatting a secret throws.
local function plainNumber(value)
	if type(value) ~= "number" then
		return false
	end
	local isSecret = G("issecretvalue")
	if type(isSecret) == "function" then
		local ok, secret = pcall(isSecret, value)
		if not ok or secret then
			return false
		end
	end
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function settings()
	local Store = ns.Store
	if type(Store) == "table" and type(Store.GetSettings) == "function" then
		return Store.GetSettings()
	end
	return {}
end

local function saveSetting(name, value)
	local Store = ns.Store
	if type(Store) == "table" and type(Store.PutSetting) == "function" then
		return Store.PutSetting(name, value)
	end
	return nil, "Store.PutSetting missing"
end

local function notifySetting(name)
	if ns.Options and type(ns.Options.NotifyChanged) == "function" then
		ns.Options.NotifyChanged(name)
	end
end

local function inCombat()
	local check = G("InCombatLockdown")
	return type(check) == "function" and check() and true or false
end

--------------------------------------------------------------------------------------------
-- Geometry
--------------------------------------------------------------------------------------------

-- The offset from the minimap's centre for an angle in degrees, 0 to the right, 90 at the top.
function Button.Offset(angle, radius)
	local radians = math.rad(angle)
	return math.cos(radians) * radius, math.sin(radians) * radius
end

-- The angle in degrees, 0 to 360, of a point relative to the minimap's centre.
function Button.AngleOf(dx, dy)
	return math.deg(math.atan2(dy, dx)) % 360
end

local function savedAngle()
	local angle = settings().minimapAngle
	if plainNumber(angle) then
		return angle % 360
	end
	return Button.DEFAULT_ANGLE
end

local function radius(minimap)
	local width = minimap:GetWidth()
	if not plainNumber(width) or width <= 0 then
		width = 140
	end
	return width / 2 + Button.EDGE
end

local function place(button, angle)
	local minimap = G("Minimap")
	if not minimap then
		return
	end
	button:ClearAllPoints()
	local x, y = Button.Offset(angle, radius(minimap))
	button:SetPoint("CENTER", minimap, "CENTER", x, y)
end

-- The cursor's angle round the minimap, both in the minimap's effective scale. Nil while either
-- cannot be read.
local function cursorAngle()
	local minimap = G("Minimap")
	local getCursor = G("GetCursorPosition")
	if not minimap or type(getCursor) ~= "function" then
		return nil
	end
	local cx, cy = getCursor()
	local mx, my = minimap:GetCenter()
	local scale = minimap:GetEffectiveScale()
	if not (plainNumber(cx) and plainNumber(cy) and plainNumber(mx) and plainNumber(my)
		and plainNumber(scale) and scale > 0) then
		return nil
	end
	return Button.AngleOf(cx / scale - mx, cy / scale - my)
end

--------------------------------------------------------------------------------------------
-- Dragging and clicks
--------------------------------------------------------------------------------------------

local function onUpdate(button)
	local angle = cursorAngle()
	if angle then
		button.angle = angle
		place(button, angle)
	end
end

local function onDragStart(button)
	if Button.IsLocked() then
		return
	end
	button:SetScript("OnUpdate", onUpdate)
end

local function onDragStop(button)
	button:SetScript("OnUpdate", nil)
	if plainNumber(button.angle) then
		local ok, reason = saveSetting("minimapAngle", button.angle)
		if not ok then
			button.angle = savedAngle()
			place(button, button.angle)
			if type(ns.say) == "function" then
				ns.say("could not save minimap position: " .. tostring(reason))
			end
		end
	end
end

local function onClick(_, mouseButton)
	if mouseButton == "RightButton" then
		if ns.Options and type(ns.Options.Open) == "function" then
			ns.Options.Open()
		end
	elseif ns.UI and type(ns.UI.Toggle) == "function" then
		ns.UI.Toggle()
	end
end

--------------------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------------------

local function now()
	local getTime = G("GetTime")
	local value = type(getTime) == "function" and getTime() or nil
	return plainNumber(value) and value or nil
end

-- The summary, read at most once per SUMMARY_TTL and never in combat. A read that throws is
-- dropped, so the tooltip still shows its hints.
local function summary()
	local at = now()
	if cached and at and cachedAt and at - cachedAt < Button.SUMMARY_TTL then
		return cached
	end
	if inCombat() then
		return cached or { lines = { { kind = "message", text = Button.COMBAT_LINE } } }
	end
	if type(Button.summarySource) ~= "function" then
		return nil
	end
	local ok, result = pcall(Button.summarySource)
	if not ok or type(result) ~= "table" then
		return nil
	end
	cached, cachedAt = result, at
	return result
end

-- The summary tooltip on any owner: this button, or the minimap dropdown's entry, which only
-- differ in what a click does.
function Button.ShowTooltip(owner, hint)
	local tooltip = G("GameTooltip")
	if not tooltip or not pcall(tooltip.SetOwner, tooltip, owner, "ANCHOR_LEFT") then
		return
	end
	tooltip:AddLine("LegacyNext", 1, 1, 1)
	local drawn = summary()
	for _, line in ipairs(drawn and drawn.lines or {}) do
		if line.kind == "challenge" then
			tooltip:AddDoubleLine(tostring(line.left), tostring(line.right), 1, 1, 1, 1, 1, 1)
		elseif line.kind == "header" then
			tooltip:AddLine(tostring(line.text), 1, 0.82, 0)
		else
			tooltip:AddLine(tostring(line.text), 0.7, 0.7, 0.7, true)
		end
	end
	tooltip:AddLine(hint or Button.HINT, 0.5, 0.5, 0.5, true)
	tooltip:Show()
end

function Button.HideTooltip()
	local tooltip = G("GameTooltip")
	if tooltip then
		tooltip:Hide()
	end
end

local function onEnter(button)
	Button.ShowTooltip(button, Button.HINT)
end

local function onLeave()
	Button.HideTooltip()
end

--------------------------------------------------------------------------------------------
-- Construction and state
--------------------------------------------------------------------------------------------

local function build(minimap)
	local button = CreateFrame("Button", BUTTON_NAME, minimap)
	button:SetSize(SIZE, SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(HIGHLIGHT)

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetPoint("TOPLEFT", 7, -5)
	background:SetColorTexture(0, 0, 0, 0.6)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture(ICON)

	-- SetMask: SimpleTextureBaseAPIDocumentation.lua:461 at 9a789c0. Square corners without it.
	button.masked = false
	for _, texture in ipairs({ background, icon }) do
		if type(texture.SetMask) == "function" and pcall(texture.SetMask, texture, ROUND_MASK) then
			button.masked = true
		end
	end

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture(BORDER)

	button:SetScript("OnClick", onClick)
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)
	button:SetScript("OnEnter", onEnter)
	button:SetScript("OnLeave", onLeave)
	return button
end

function Button.SetSummarySource(fn)
	Button.summarySource = fn
	cached, cachedAt = nil, nil
end

function Button.IsHidden()
	return settings().minimapHidden == true
end

function Button.IsLocked()
	return settings().minimapLocked == true
end

local function apply()
	local button = Button.button
	if not button then
		return
	end
	button.angle = savedAngle()
	place(button, button.angle)
	if Button.IsHidden() then
		button:Hide()
	else
		button:Show()
	end
end

-- Builds the button once Minimap exists, at PLAYER_LOGIN. True, or nil plus a reason.
function Button.Init()
	if Button.button then
		apply()
		return true
	end
	local minimap = G("Minimap")
	if not minimap then
		return nil, "no Minimap frame"
	end
	local ok, built = pcall(build, minimap)
	if not ok then
		return nil, "could not build: " .. tostring(built)
	end
	Button.button = built
	apply()
	return true
end

function Button.SetHidden(hidden)
	local ok, reason = saveSetting("minimapHidden", hidden and true or false)
	if not ok then
		return ok, reason
	end
	apply()
	notifySetting("minimapHidden")
	return true
end

function Button.SetLocked(locked)
	local ok, reason = saveSetting("minimapLocked", locked and true or false)
	if not ok then
		return ok, reason
	end
	notifySetting("minimapLocked")
	return true
end

-- What the button decided, for /lgn uidump.
function Button.Describe()
	local button = Button.button
	if not button then
		return { created = false }
	end
	return {
		created = true,
		shown = button:IsShown() and true or false,
		angle = plainNumber(button.angle) and math.floor(button.angle + 0.5) or nil,
		locked = Button.IsLocked(),
		masked = button.masked and true or false,
	}
end
