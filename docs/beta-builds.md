# Forever beta build log

What changed underneath us, per re-pin of `vendor/wow-ui-source`. Newest first.

Written by the `beta-build-bump` skill, which runs whenever Blizzard pushes a beta build.
"Touches us" means the Legacy API surface LegacyNext actually calls — see
`.claude/skills/beta-build-bump/references/watchlist.txt` for the list. A build that moved
only `version.txt` gets an entry too; knowing a build was boring is worth recording, and a
gap in this file should mean "nobody checked", not "nothing happened".

Beta opened 2026-09-17. Launch is 2026-11-04.

## 1.60.1.70124 — 2026-09-30

Pin: `bd2470a` → `966519c` (mirror commit dated 2026-09-30). Covers two builds, since
`1.60.1.70058` (`cde14c6`, 2026-09-29) was never pinned. `## Interface:` stays 16001, which is
what the formula computes from `1.60.1.70124` and what the `.toc` reads. That is its third data
point, and it still agrees.

**Does not touch us**

- One vendored file changed, `Blizzard_GameTooltip/Mainline/GameTooltip.lua`: a nil guard on
  `GamepadMode.FrameControlsManager` in `GameTooltip_OnShow` (`:380-386`). We cite only
  `GameTooltip.xml`, which did not move. `watchlist.txt` and `constants.diff` are empty.
- The other 9 changed files are outside the sparse checkout: gamepad action bars, world map,
  map data providers and item text. None of the four outside directories that `vendor/PINS.md`
  lists changed.

**Citations**

`CITATIONS_SUSPECT` did not fire. `verify_citations.py` reported two broken lines, both false
positives in files that did not change: `UnitDocumentation.lua:3869`, as at the last bump, and
this file's own `SimpleScriptRegionAPIDocumentation.lua:95`, which still reads
`Name = "EnableMouseWheel"`.

**Needs in-game confirmation**

- "No secrets on our surface" was last tested on 69913. `/lgn probe` on this build is queue row
  **D10** in `docs/ingame-commands.md`.

## 1.60.1.70009 — 2026-09-26

Pin: `70ef1b2` → `bd2470a` (mirror commit dated 2026-09-24). First real bump; the build number
went forwards. `## Interface:` stays 16001, which is what `major*10000 + minor*100 + patch`
computes from `1.60.1.70009` and what the committed `.toc` already reads. That is the second
data point for the formula, and it agrees.

**Does not touch us**

- `Blizzard_LegacySystem`, 3 files, all gamepad and cosmetic. `SetupGamepadTreeFooter` moved
  the undo/reset bindings from `CreateTapOrHoldPromptedBinding(GAMEPAD_TRIGGER_RIGHT, ...)` to
  `CreatePromptedBinding(GAMEPAD_FACE_TOP, ...)` with a named binding and a `conditions` list
  (`Blizzard_LegacySystem.lua:226-397`), and `Blizzard_LegacyTree.xml` retargets the two
  `mappedButtonKey` KeyValues to match (`:172`, `:196`). The rest is two background textures
  nudged a pixel (`Blizzard_LegacyChallenges.xml:43-44`, `Blizzard_LegacyTree.xml:297-298`).
  Those are `UndoButton` / `ResetButton` click paths, which we never call — read-only trait
  access, always.
- `LegacyConstantsDocumentation.lua` did not move. `constants.diff` is empty, so all six
  `Constants.LegacyConsts` values in CLAUDE.md stand at this pin.
- No doc file for Achievements, `C_Traits`, or `C_MajorFactions` changed, and `watchlist.txt`
  is empty — no symbol LegacyNext calls appears anywhere in the diff.
- 30 `Blizzard_APIDocumentationGenerated` files changed and two were added
  (`FlyoutDocumentation.lua`, `NameUtilDocumentation.lua`). Nothing was deleted, so no
  namespace went away.
- The remaining 25 changed files are `Blizzard_SharedXML`, `Blizzard_FrameXML`,
  `Blizzard_UIPanelTemplates` and `Blizzard_AddOnList` — adjacent to the templates we inherit,
  but no template or font object named in `docs/ui-templates.md` changed shape.

**Worth knowing**

- Four functions gained a `ChecksForbiddenAspects` entry of
  `{ Argument = "self", Aspect = Enum.ForbiddenAspect.ScriptedInput }`: `FocusEnter`,
  `FocusExit`, `MouseDown` and `MouseUp` in `SimpleScriptRegionAPIDocumentation.lua`
  (`:110`, `:122`, `:600`, `:612`). Those are the only four lines the diff adds. Neither the
  field nor the aspect is new — the same file already carried `ScriptBindings` and
  `QueryFocus` entries (`:52`, `:262`, `:369`, `:495`, `:716`), and `ScriptedInput` was already
  on `SimpleEditBoxAPIDocumentation.lua` and `SimpleButtonAPIDocumentation.lua`. This is the
  Midnight restriction machinery reaching synthetic input, and we call none of those four.
  Read it as "Blizzard documented a field", not "Blizzard added a behaviour".
- `HideUIPanel` and `ShowUIPanel` now guard their `EventRegistry:TriggerEvent` broadcast on
  `frame:IsShown()` (`UIParentPanelManager.lua:873-875`, `:907-909`). The combat early-return
  through `CheckProtectedFunctionsAllowed()` is unchanged, so the close-button gotcha in
  `docs/ui-templates.md` still holds — the citation just shifted two lines.

**Citations re-derived**

`CITATIONS_SUSPECT` fired on three docs. Five line numbers in `docs/ui-templates.md` moved and
were re-derived against the new checkout, not nudged:

| Was | Now | Lands on |
|---|---|---|
| `SimpleScriptRegionAPIDocumentation.lua:747` | `:751` | `Name = "Show"` |
| `:355` | `:357` | `Name = "Hide"` |
| `:651` | `:653` | `Name = "SetParent"` |
| `:538` | `:540` | `Name = "IsProtected"` |
| `UIParentPanelManager.lua:903-917` | `:905-921` | `function HideUIPanel` through the `CheckProtectedFunctionsAllowed()` return |

Confirmed unmoved and left alone: `SimpleScriptRegionAPIDocumentation.lua:95` / `:97` /
`:10`, `UIParentPanelManager.lua:21` and `:1102-1112`, `docs/status.md`'s `:854-861`, and all
four `AddonList.lua` citations in `docs/icon-design.md` — `AddonList.lua` changed only at
`:660`, far below them. `verify_citations.py` reported `UnitDocumentation.lua:3869` broken;
that is a false positive. The line still reads `Name = "PlayerRegenDisabled"` and the prose
cites it by its `LiteralName`, `PLAYER_REGEN_DISABLED`.

## 1.60.1.69913 — 2026-09-18

Pin: initial → `70ef1b2`

Baseline entry, recorded when the skill was written rather than by a bump. This is the
commit `vendor/PINS.md` has always pointed at.

**Does not touch us**

The preceding mirror commits (the list recorded here on 2026-09-18 repeated two build numbers,
`69876` and `69893`, and the shallow clone cannot re-derive it) changed
nothing in `Blizzard_LegacySystem`, `Blizzard_LegacyChallengeTracker`,
`Blizzard_APIDocumentationGenerated`, or `Blizzard_AchievementUI`. Only `version.txt` moved.

**Worth knowing**

Build numbers on this mirror are not monotonic — the recorded sequence went forwards, backwards,
then forwards again, because commits get re-pushed out of order. Newest commit does not mean
highest build. The skill flags this as `BUILD_WENT_BACKWARDS` rather than guessing.

**2026-09-19, no pin move.** The sparse checkout was widened twice at this same SHA, first by
twelve UI directories for `docs/ui-templates.md`, then by `Blizzard_AddOnList` for
`docs/icon-design.md`. `vendor/PINS.md` lists them. Recorded so the gap does not read as
"nobody checked".

All six values in CLAUDE.md's Legacy constants table were confirmed against
`Blizzard_APIDocumentationGenerated/LegacyConstantsDocumentation.lua` at this commit.
