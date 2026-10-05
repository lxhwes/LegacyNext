# Forever beta build log

What changed underneath us, per re-pin of the shared Forever checkout (`vendor/wow-ui-source`
until 2026-10-04, `$WOW_FOREVER_SRC/wow-ui-source` since). Newest first.

Written by the `beta-build-bump` skill, which runs whenever Blizzard pushes a beta build.
"Touches us" means the Legacy API surface LegacyNext actually calls — see
`.claude/forever-tools/watchlist.txt` for the list. A build that moved
only `version.txt` gets an entry too; knowing a build was boring is worth recording, and a
gap in this file should mean "nobody checked", not "nothing happened".

Beta opened 2026-09-17. Launch is 2026-11-04.

## 1.60.1.70170 — 2026-10-01

Pin: `966519c` → `9a789c0` (mirror commit dated 2026-10-01). `## Interface:` stays 16001, which
is what the formula computes from `1.60.1.70170` and what the `.toc` reads. Fourth data point,
still agreeing.

**Touches us**

No constant, signature, struct or doc file on our surface changed. `constants.diff` is empty. Every
watchlist hit is a Blizzard call site, and three of them change what our docs say:

- `GetTreeCurrencyInfo`'s `excludeStagedChanges` flipped from `true` to `false` in Blizzard's
  summary read (`Blizzard_LegacySystemUtil.lua:41-43`), to match the talent panel while changes
  are staged. `Api` still passes `true` (`LegacyNext/Api/Api.lua:653`). Our numbers now differ
  from Blizzard's summary only while a player has unsaved tree edits. Left as is; see
  `docs/status.md`.
- `ToggleLegacySystemUI` now returns early when `GetCurrentRenownLevel(2802) <= 0`
  (`Blizzard_LegacySystem_Bootstrap.lua:8-10`). At zero points Blizzard's panel no longer opens,
  and that covers the key binding too. This bears on the "open Blizzard's panel on one challenge" idea.
- The reward track reads `GetMajorFactionData` on every `Refresh` and treats nil as "not available
  yet" (`Blizzard_LegacyRewardTrack.lua:168-172`). `Api.GetRewardTrack` already returns nil plus a
  reason for it (`LegacyNext/Api/Api.lua:541-545`), and each window open re-reads.

**Does not touch us**

- The other Legacy edits move currency reads behind a cache, `LegacySystem.GetCurrencyInfo` and
  `RegisterCurrencyInfoCallback` (`Blizzard_LegacySystemUtil.lua:62-73`). The cap tooltip still
  formats `maxQuantity`, now from `OnEnter` (`Blizzard_LegacyTree.lua:303`).
- API docs: six files, none on our surface. New `C_Spell.GetItemCooldown`, `UnitUsesAmmo`,
  `PLAYER_PVP_FLAG_CHANGED`, and `EventToastEventType.RenownFactionLeveledUp` (27).
- New `Blizzard_AchievementUI/Camelot/Blizzard_AchievementUI.lua`, one line setting
  `ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS = 0`.
- Outside the sparse checkout, `Blizzard_Professions` moved the parent-line expression into
  `Professions.GetEffectiveSkillLineID()` (`Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:1678-1681`).
  The join `CLAUDE.md` describes is unchanged. Its line numbers moved.

**Citations**

`CITATIONS_SUSPECT` fired on `docs/legacy-internals.md`, `docs/ui-templates.md` and this file.
`verify_citations.py` caught 3 broken lines. A diff-based line map between the two pins found the
rest, which had shifted onto other lines and still passed. All of them were re-derived and checked by content in
`docs/legacy-internals.md`, `docs/ui-templates.md` and `CLAUDE.md`. Older entries in this file
keep their own pins and were left alone. One drift predates this bump:
`MainMenuBarMicroButtons.lua:1045` had read `end` since at least `966519c`, and is now `:1054`.

**Needs in-game confirmation**

- D10, the probe, now targets 70170.

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
