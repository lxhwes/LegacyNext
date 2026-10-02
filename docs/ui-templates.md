# UI templates on the Forever branch

Read-only research against `vendor/wow-ui-source`, written 2026-09-19 at pin
`70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e` (`1.60.1.69913`) and re-checked 2026-09-26 at
`bd2470aed543f72697a044e989285b6c83e63f73` (`1.60.1.70009`), which is where the line numbers
below now point. Five of them moved in that bump; see `docs/beta-builds.md` for which. Checked
again 2026-09-30 at `966519cf0ad2c10301ea011a88c14b25697c9687` (`1.60.1.70124`), where none
moved.
Paths are relative to `Interface/AddOns/`. Line numbers are pin-relative; re-run
`.claude/skills/forever-api-lookup/scripts/verify_citations.py` after a
bump. That script only resolves `.lua` citations, so the `.xml` lines here were checked by hand.

Tiers: **A** defined in vendored source at the cited line. **B** referenced in vendored source
but defined C-side or elsewhere. **C** not found; needs the game.

**Two of these are now confirmed in game, not just at the pin** [U1, 2026-09-19]: `/lgn uidump`
reported `frameTemplate = "BasicFrameTemplateWithInset"` and
`scrollTemplate = "UIPanelScrollFrameTemplate"`, so neither `pcall` fallback fired on build
1.60.1 (69913). Tier A held for both. ~~The Tier C items below — auto-ellipsis (U2) and combat
behaviour — are still open.~~ U2 settled most of them on 70124, 2026-10-01: the frame reads
`IsProtected() = false, false`, both ScrollBox templates exist at runtime, and truncation is
detectable. Whether a clipped string draws `...` is the one part still open.

Scope note: this pass widened the sparse checkout (same SHA) with `Blizzard_SharedXML{,Base,Game}`,
`Blizzard_FrameXML{,Base,Util}`, `Blizzard_Fonts_Shared`, `Blizzard_UIParent{,PanelManager,Util}`,
`Blizzard_UIPanelTemplates` and `Blizzard_GameTooltip`. `vendor/PINS.md` records the widened set
under "Widened on 2026-09-19".

TOC tags: `[Family]` resolves to `Mainline/` and `[Game]` to `Camelot/` on Forever
(`Blizzard_SharedXML/Blizzard_SharedXML.toc:31` loads `[Game]\NineSliceLayoutOverrides.lua
[AllowLoadGameType camelot]`, and the only copy is under `Camelot/`).

## 1. WowScrollBoxList stack

All Tier A, all in `Blizzard_SharedXML`, which is `## AllowLoad: Both` with no LoadOnDemand
(`Blizzard_SharedXML/Blizzard_SharedXML.toc:2`).

| Symbol | Where |
|---|---|
| `WowScrollBoxList` (Frame template, mixin `ScrollBoxListMixin`) | `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml:4` |
| `MinimalScrollBar` (EventFrame template) | `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml:15` |

Both templates exist at runtime: `C_XMLUtil.GetTemplateInfo` returned a value for each
[verified in game 2026-10-01, 70124, U2].
| `CreateScrollBoxListLinearView(top, bottom, left, right, spacing)` | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua:246` |
| `view:SetElementInitializer(frameTemplateOrFrameType, initializer)` | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxListView.lua:496` |
| `view:SetElementExtent(extent)` | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua:102` |
| `ScrollUtil` table / `ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)` | `Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua:11`, `:137` |
| `CreateDataProvider(tbl)` | `Blizzard_SharedXML/DataProvider.lua:277` |
| `scrollBox:SetDataProvider(dataProvider, retainScrollPosition)` | `Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:703` |
| `ScrollBoxConstants.DiscardScrollPosition` | `Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:18` |
| `CreateFrameFactory` (what turns `"Button"` into a pooled frame) | `Blizzard_SharedXMLBase/FrameFactory.lua:58` |

Blizzard call sites. `Blizzard_LegacyChallengeCategoryList.xml:61` and `:68` inherit
`WowScrollBoxList` and `MinimalScrollBar`; the Lua wires a tree view at
`Blizzard_LegacySystem/Blizzard_LegacyChallengeCategoryList.lua:39-79`. The plain linear shape we
want is `Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:646-651`:
`CreateScrollBoxListLinearView()`, `SetElementInitializer(template, fn)`,
`ScrollUtil.InitScrollBoxListWithScrollBar`. `Blizzard_LegacyChallengeDetailPane.lua:43-53`
builds a `CreateDataProvider()` and calls `SetDataProvider`;
`Blizzard_LegacyChallenges.lua:41` passes `ScrollBoxConstants.DiscardScrollPosition`.

Lua-only setup, following those sites:

```lua
local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
local view = CreateScrollBoxListLinearView()
view:SetElementInitializer("Button", function(row, data) ... end)
view:SetElementExtent(18)
ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
box:SetDataProvider(CreateDataProvider(rows))
```

Two rules come from the source, not from taste. First, a bare frame type is supported (the
mixin's own comment shows `SetElementInitializer("Button", Initializer)`,
`ScrollBoxListView.lua:494`; `FrameFactory.lua:17-25` falls back to a native type when
`GetTemplateInfo` returns nil). But then `SetElementExtent` is mandatory: `Init` errors
"Failed to assign an explicit element extent" when the initializer is not a template and no
extent or calculator is set (`ScrollBoxListView.lua:41-49`). Second, `SetDataProvider` errors
if no view has been installed yet (`ScrollBox.lua:704-707`), so `Init...WithScrollBar` comes
first. `CreateFrame("EventFrame", ...)` from Lua is Blizzard's own pattern
(`Blizzard_SharedXML/SecureUIPanelTemplates.lua:23`).

Global vs mixin: `CreateScrollBoxListLinearView`, `CreateDataProvider`, `ScrollUtil`,
`ScrollBoxConstants` are globals. `SetElementInitializer`, `SetElementExtent` live on the view
object; `SetDataProvider`, `ForEachFrame`, `ScrollToElementDataIndex` on the scroll box. The
templates are XML names, reachable without creating a frame via
`C_XMLUtil.GetTemplateInfo(name)`, documented `MayReturnNothing = true`
(`Blizzard_APIDocumentationGenerated/XMLUtilDocumentation.lua:11-23`).

## 2. UIPanelScrollFrameTemplate fallback

Tier A. `UIPanelScrollFrameTemplate` is at `Blizzard_SharedXML/SecureScrollTemplates.xml:44`,
inheriting `UIPanelScrollFrameCodeTemplate` (`:36`) which binds `OnLoad` to
`UIPanelScrollFrame_OnLoad`, `OnScrollRangeChanged` to `ScrollFrame_OnScrollRangeChanged`,
`OnVerticalScroll` to `ScrollFrame_OnVerticalScroll` and `OnMouseWheel` to
`ScrollFrameTemplate_OnMouseWheel` (`:38-41`). Handlers: `SecureScrollTemplates.lua:27`, `:64`,
`:134`, `:54`. The template supplies its own `$parentScrollBar` slider with `parentKey="ScrollBar"`
anchored to the frame's right edge (`SecureScrollTemplates.xml:46-51`).

What it needs from us: a scroll child via `SetScrollChild` (documented, `IsProtectedFunction`,
`SimpleScrollFrameAPIDocumentation.lua:91`) with an explicit width and height. The scrollbar
range is derived, not sized by us: `ScrollFrame_OnScrollRangeChanged` reads
`GetVerticalScrollRange()` and calls `SetMinMaxValues(0, yrange)` (`SecureScrollTemplates.lua:64-73`).
The handlers use `self.ScrollBar` first and fall back to `envTable[name.."ScrollBar"]`
(`:66`; `:28` spells it `envTable[self:GetName().."ScrollBar"]`), so an unnamed frame is fine, which matches the Debug window working in game.

The file is marked deprecated in favour of ScrollBox (`SecureScrollTemplates.xml:3-6`) and
`HybridScrollFrame` is "Retained only for addons" (`Blizzard_SharedXML.toc:239`), but both still
ship and still work. Do not confuse it with `ScrollFrameTemplate` (`SecureUIPanelTemplates.xml:24`,
handler `ScrollFrame_OnLoad` at `SecureUIPanelTemplates.lua:1`), a newer template that creates a
`MinimalScrollBar` at load from `Blizzard_SharedXML/Mainline/ScrollDefine.lua:1`.

A bare `CreateFrame("ScrollFrame")` with no template is viable on paper: `SetScrollChild`,
`SetVerticalScroll` (`SimpleScrollFrameAPIDocumentation.lua:103`), `GetVerticalScrollRange` (`:65`)
and `EnableMouseWheel` (`SimpleScriptRegionAPIDocumentation.lua:95`) are documented, and the
`OnMouseWheel` / `OnScrollRangeChanged` script names are proven by the XML above. Tier A for the
pieces, Tier C assembled, since no Blizzard file does it without a template.

## 3. Font objects

All Tier A, all in `Blizzard_Fonts_Shared/Shared/`, which loads unconditionally
(`Blizzard_Fonts_Shared/Blizzard_Fonts_Shared.toc:5`, `:10`). Nothing under `Mainline/` redefines
these names.

| Font | Line | Base | Colour |
|---|---|---|---|
| `GameFontNormal` | `FontStyles.xml:50` | `SystemFont_Shadow_Med1` (12pt) | `NORMAL_FONT_COLOR` (gold) |
| `GameFontNormalSmall` | `FontStyles.xml:56` | `SystemFont_Shadow_Small` (10pt) | gold |
| `GameFontHighlight` | `FontStyles.xml:62` | GameFontNormal | `WHITE_FONT_COLOR` |
| `GameFontHighlightSmall` | `FontStyles.xml:92` | GameFontNormalSmall | white |
| `GameFontDisable` | `FontStyles.xml:86` | GameFontNormal | 0.5 grey |
| `GameFontDisableSmall` | `FontStyles.xml:112` | GameFontNormalSmall | `DISABLED_FONT_COLOR` |
| `GameFontNormalLarge` | `FontStyles.xml:172` | `SystemFont_Shadow_Large` | gold |
| `NumberFontNormal` | `FontStyles.xml:389` | `NumberFont_Outline_Med` | `HIGHLIGHT_FONT_COLOR` |
| `ChatFontNormal` | `Fonts.xml:1373` | `NumberFont_Shadow_Med` | white |
| `SystemFont_Shadow_Small` | `Fonts.xml:39` | FontFamily, 10pt FRIZQT | none set |

Safe defaults: header line 1 `GameFontNormalLarge`, line 2 `GameFontHighlightSmall`; row
`GameFontHighlight` (white body text; gold `GameFontNormal` reads as a label); dimmed row
`GameFontDisable`; divider label `GameFontNormalSmall`. `SystemFont_Shadow_Small` is a colourless
`FontFamily` with no `SetFontObject` call site in the checkout; skip it.

## 4. Backdrop, panel, button templates, Escape

| Symbol | Tier | Where |
|---|---|---|
| `BackdropTemplate` | A | `Blizzard_SharedXML/Backdrop.xml:5` |
| `BackdropTemplateMixin`, `:SetBackdrop(info)` | A | `Blizzard_SharedXML/Backdrop.lua:142`, `:336` |
| `BACKDROP_DIALOG_32_32`, `BACKDROP_TUTORIAL_16_16` | A | `Backdrop.lua:17`, `:132` |
| `ButtonFrameTemplate` | A | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:711` |
| `PortraitFrameTemplate` | A | `SharedUIPanelTemplates.xml:658` |
| `DefaultPanelTemplate` | A | `SharedUIPanelTemplates.xml:528` |
| `BasicFrameTemplate` / `BasicFrameTemplateWithInset` | A | `Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:619`, `:646` |
| `UIPanelCloseButton` / `UIPanelCloseButtonNoScripts` | A | `SharedUIPanelTemplates.xml:148`, `:134` |
| `UIPanelButtonTemplate` | A | `SharedUIPanelTemplates.xml:315` |
| `UISpecialFrames` | A | `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:21` |

`SetBackdrop` is not in the generated docs at all; it is Lua on the mixin, so the frame must be
created with `"BackdropTemplate"`. The mixin needs an `edgeFile` or `bgFile` or it clears itself
(`Backdrop.lua:337-345`) and it renders through `NineSliceUtil.ApplyLayout`
(`Backdrop.lua:329`, defined `Blizzard_SharedXML/NineSlice.lua:160`). Nothing else is required.

Least surprising standalone panel: `BasicFrameTemplateWithInset`. It is textures plus a
`TitleText` FontString (`UIPanelTemplates.xml:577`) and a `CloseButton` (`:615`), with no mixin
and no portrait. `ButtonFrameTemplate` inherits `PortraitFrameBaseTemplate` with
`PortraitFrameMixin, FocusFramesInterfaceMixin` (`SharedUIPanelTemplates.xml:566`, `:687`); the
title lives in `self.TitleContainer.TitleText` via `TitledPanelMixin`
(`Blizzard_SharedXML/PortraitFrame.lua:2-15`). `DefaultPanelTemplate` also carries
`FocusFramesInterfaceMixin` (`:478`). `Blizzard_UIPanelTemplates` has no LoadOnDemand line
(`Blizzard_UIPanelTemplates.toc:1-2`).

Close button gotcha. `UIPanelCloseButton_OnClick` calls `HideUIPanel(parent)`
(`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:150-160`), and `HideUIPanel` returns
early when `InCombatLockdown() and not issecure()` after showing the "action blocked" message
(`UIParentPanelManager.lua:905-921`, `:854-861`). An addon click is insecure, so on our frame
that X does nothing in combat. Use `UIPanelCloseButtonNoScripts` and set `OnClick` to
`parent:Hide()` ourselves. The Camelot override anchors the default close button at
`TOPRIGHT -2, 1` (`Blizzard_SharedXML/Camelot/SharedUIPanelTemplates.lua:3-5`).

`UIPanelButtonTemplate` inherits `UIPanelButtonNoTooltipTemplate`
(`Blizzard_SharedXML/SecureUIPanelTemplates.xml:39`) which supplies `ButtonText` and
`GameFontNormal` / `GameFontHighlight` / `GameFontDisable` (`:81-84`), so `SetText` just works.

`UISpecialFrames` is a plain Lua table of global frame names. `CloseSpecialWindows` iterates it
with `_G[value]` and calls `:Hide()` (`UIParentPanelManager.lua:1102-1112`), so `tinsert` of a
named frame is the whole contract. It is not in `Blizzard_UIParent/UIParent.lua`, which is 11
lines on this branch; the panel manager owns it.

## Key binding and AddOns-list category (2026-10-01, at `966519c`)

Tier B: read from Blizzard's own files, unseen in game until **U7**.

- `Bindings.xml` loads by file name. None of the eight Blizzard addons that ship one lists it in
  its TOC (for example `Blizzard_PingUI/Blizzard_PingUI.toc`). The loader itself is client-side.
- The row label is `BINDING_NAME_<name>` (`Blizzard_SharedXML/BindingUtil.lua:142-149`).
- `category="ADDONS"` titles the section through `_G.ADDONS`, or the raw string if that is
  missing (`Blizzard_SettingsDefinitions_Frame/Keybindings.lua:220-227`, `:248-249`).
- A `HEADER` binding draws only a spacer (`Keybindings.lua:251-252`), so no
  `BINDING_HEADER_*` global is defined.
- `## Category` is read at `Blizzard_AddOnList/AddonList.lua:456`, and grouping needs the exact
  same string (`:486-490`). No localized `Category-enUS` form is read.

## 5. Text truncation and GameTooltip

FontString methods, all Tier A in
`Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua`: `SetWordWrap(wrap)`
`:720`, `SetMaxLines(maxLines)` `:580`, `SetNonSpaceWrap(wrap)` `:590`, `IsTruncated()` `:442`,
`GetWrappedWidth()` `:428`, `GetUnboundedStringWidth()` `:398`, `SetText` `:664`, `SetFontObject`
`:529`, `SetJustifyH` `:560`. All `SecretArguments = "AllowedWhenUntainted"` except `SetText`,
which is `AllowedWhenTainted`.

`GetStringHeight()` is at `:325` (checked at `966519c`, 1.60.1.70124), marked
`SecretWhenAnchoringSecret`. Blizzard's `ScrollingFontMixin` sizes wrapped text with it, calling
`SetWidth` first (`Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua:321-325`). The list
footnote follows that order. A height check in game is part of U4.

Auto-ellipsis is **Tier C**. No documentation line mentions an ellipsis and no Legacy XML sets
`wordwrap="false"`. Blizzard does treat "truncated" as a queryable state:
`ShrinkUntilTruncateFontStringMixin` steps fonts down until `IsTruncated()` is false
(`Blizzard_SharedXML/SecureUtil.lua:17-22`) and `ListHeaderVisualMixin` shows a tooltip when
`IsTruncated()` (`Blizzard_SharedXML/ListTemplates.lua:119-122`). That proves clipping is
detectable, not that "..." is drawn. Plan on `IsTruncated()` plus a tooltip.

[verified in game 2026-10-01, 70124, U2] A 120 px, no-wrap `GameFontHighlight` string holding
"Reach exalted reputation with the Frostwolf Clan" read `IsTruncated() = true`, and
`GetStringWidth()` and `GetUnboundedStringWidth()` both read 300.67. **So `GetStringWidth`
reports the full text width on a clipped string, not the drawn width.** Detect truncation with
`IsTruncated()`, never by comparing widths. Whether the clipped string ends in "..." on screen
is still open.

GameTooltip: `SetOwner`, `AddLine`, `Show` are absent from the generated docs (no
`Name = "SetOwner"` anywhere in the 639 files), so **Tier B**. Blizzard's Legacy code does exactly
our shape: `GameTooltip:SetOwner(self, "ANCHOR_RIGHT")`, `GameTooltip:AddLine(rewardText)`,
`GameTooltip:Show()` at `Blizzard_LegacySystem/Blizzard_LegacyChallenges.lua:323-329`. The frame
itself is `Blizzard_GameTooltip/Mainline/GameTooltip.xml:249`.

## 6. Combat lockdown

`InCombatLockdown()` is documented, bare global, `RestrictedActionsDocumentation.lua:45`.
`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` are documented events,
`UnitDocumentation.lua:3884`, `:3890`. Tier A for all three.

Whether a plain frame needs any handling: the docs point to "no", but only by inference. The
protection flags are per-function and per-object. `Show` and `Hide`
(`SimpleScriptRegionAPIDocumentation.lua:751`, `:357`) and FontString `SetText` carry no
`IsProtectedFunction`; `SetPoint`, `SetSize`, `SetParent`, `SetScrollChild`, `SetVerticalScroll`,
`EnableMouseWheel` and `EnableMouse` do (`SimpleScriptRegionResizingAPIDocumentation.lua:137`,
`:165`; `SimpleScriptRegionAPIDocumentation.lua:653`, `:97`, `:75`; `SimpleScrollFrameAPIDocumentation.lua:93`,
`:105`). Those flags gate on the object being protected: `IsProtected()` and
`CanChangeProtectedState()` are per-region (`SimpleScriptRegionAPIDocumentation.lua:540`, `:10`),
and `C_RestrictedActions.CheckAllowProtectedFunctions(object, silent)` is documented as
"permissions to call protected functions on the supplied object"
(`RestrictedActionsDocumentation.lua:11-27`). A frame we create with no secure template or
attribute is not protected, so the flagged calls are not blocked on it. The claim "unprotected
frames are unaffected in combat" itself is client behaviour, **Tier C**, and cheap to confirm:
`frame:IsProtected()` should return `false, false`. It does: `false,false` on `LegacyNextFrame`
[verified in game 2026-10-01, 70124, U2].

Separate axis: `Enum.AddOnRestrictionType` (`Combat`, `Encounter`, `ChallengeMode`, `PvPMatch`,
`Map`, `Chat`; `RestrictedActionsConstantsDocumentation.lua:26-31`) and
`ADDON_RESTRICTION_STATE_CHANGED` (`RestrictedActionsDocumentation.lua:99`) are the Midnight
secret-value machinery. They affect what `Api/` reads, not whether the frame may be shown.

## Recommended feature-detect

**Superseded 2026-09-19.** The settled scroll decision is `UIPanelScrollFrameTemplate` via
`pcall`, falling back to a bare `ScrollFrame`; ScrollBox is not used. See `docs/status.md`,
"The five open 3b decisions, settled", and `LegacyNext/UI/UI.lua:103`. The block below is kept
as research for the ScrollBox path, should U1 reopen it.

If the ScrollBox list is ever built, all of these must be non-nil first; otherwise fall through.

```lua
local ok = type(CreateScrollBoxListLinearView) == "function"
  and type(CreateDataProvider) == "function"
  and type(ScrollUtil) == "table"
  and type(ScrollUtil.InitScrollBoxListWithScrollBar) == "function"
  and type(ScrollBoxConstants) == "table"
  and C_XMLUtil and type(C_XMLUtil.GetTemplateInfo) == "function"
  and C_XMLUtil.GetTemplateInfo("WowScrollBoxList") ~= nil
  and C_XMLUtil.GetTemplateInfo("MinimalScrollBar") ~= nil
```

Wrap every `CreateFrame(..., template)` in `pcall` regardless. Fallback is the already-proven
`pcall(CreateFrame, "ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")` with a sized
scroll child and hand-built rows; second fallback is a bare `ScrollFrame` with
`SetVerticalScroll` driven from `OnMouseWheel`. Frame chrome: `BasicFrameTemplateWithInset`
if `C_XMLUtil.GetTemplateInfo` finds it, else `BackdropTemplate` with `BACKDROP_DIALOG_32_32`.
