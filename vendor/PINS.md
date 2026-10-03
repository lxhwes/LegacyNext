# Vendored reference pins

Read-only Blizzard UI source. Nothing here is shipped, imported, or copied into the addon —
it exists so API behavior can be checked against the forever branch instead of assumed from
retail. The checkout itself is gitignored; this file is the record.

## wow-ui-source

| | |
|---|---|
| Remote | https://github.com/Gethe/wow-ui-source.git |
| Branch | `forever` |
| Commit | `9a789c074b8e73c5d604ef2d6af3bb5b3aefb348` |
| `version.txt` | `1.60.1.70170` |
| Pinned on | 2026-10-01 (was `966519c`, `1.60.1.70124`, 2026-09-30; `bd2470a`, `1.60.1.70009`, 2026-09-26; before that `70ef1b2`, `1.60.1.69913`, 2026-09-18) |

Sparse checkout (cone mode) covers only:

```
Interface/AddOns/Blizzard_LegacySystem
Interface/AddOns/Blizzard_LegacyChallengeTracker
Interface/AddOns/Blizzard_APIDocumentationGenerated
Interface/AddOns/Blizzard_AchievementUI
version.txt
```

All four directories were present at `70ef1b2`, `bd2470a`, `966519c` and this commit, `9a789c0`.

Widened on 2026-09-19 (then at `70ef1b2`) for the UI template research in
`docs/ui-templates.md` (22 MB total afterwards):

```
Interface/AddOns/Blizzard_SharedXML
Interface/AddOns/Blizzard_SharedXMLBase
Interface/AddOns/Blizzard_SharedXMLGame
Interface/AddOns/Blizzard_FrameXML
Interface/AddOns/Blizzard_FrameXMLBase
Interface/AddOns/Blizzard_FrameXMLUtil
Interface/AddOns/Blizzard_Fonts_Shared
Interface/AddOns/Blizzard_UIParent
Interface/AddOns/Blizzard_UIParentPanelManager
Interface/AddOns/Blizzard_UIParentUtil
Interface/AddOns/Blizzard_UIPanelTemplates
Interface/AddOns/Blizzard_GameTooltip
Interface/AddOns/Blizzard_AddOnList
```

`Blizzard_AddOnList` was added later the same day for the icon research in
`docs/icon-design.md`. Add them with `git sparse-checkout add <path>...` after the recreate
step below; the citations in `docs/ui-templates.md`, `docs/icon-design.md` and
`LegacyNext/UI/UI.lua` resolve only with them present. All seventeen were still present at
`bd2470a`, checked directory by directory on 2026-09-26, again at `966519c` on 2026-09-30, and at `9a789c0`
on 2026-10-01.

Widened again on 2026-10-02, at `9a789c0`, for the beta2 minimap button and settings page:

```
Interface/AddOns/Blizzard_Settings
Interface/AddOns/Blizzard_Settings_Shared
Interface/AddOns/Blizzard_Minimap
```

Before that widening, `Blizzard_Minimap` was read with `git show` and listed below as outside
the set. It is inside now.

Six directories cited across the docs are still outside this set: `Blizzard_MicroMenu` and
`Blizzard_SharedTalentUI` (`docs/legacy-internals.md`), `Blizzard_MajorFactions`
(`docs/legacy-internals.md`, toast events), `Blizzard_Professions` (`CLAUDE.md`,
`docs/status.md`) and `Blizzard_Minimap` (`LegacyNext/Core.lua`, `docs/ingame-commands.md`,
`docs/icon-design.md`, the addon compartment; read with `git show 966519c:<path>`).
`Blizzard_FrameXML` and `Blizzard_FrameXMLBase` were on this list until the
widening above brought them in. They were read by running `git sparse-checkout set Interface`
at an earlier pin — 53 MB, 4405 files — and then narrowing back. Widen the same way to re-check
them; the pin does not move. The whole-tree diff from `bd2470a` to `966519c` touched none of the
five. The diff from `966519c` to `9a789c0` touches three. `Blizzard_MajorFactions` changed only an
`.xml`, and we cite its `.lua`. `Blizzard_MicroMenu` and `Blizzard_Professions` changed, and the
citations into them in `CLAUDE.md` and `docs/legacy-internals.md` were re-derived by `git show`
at the new pin on 2026-10-01. `Blizzard_Minimap` did not change, so the compartment citations
hold. The professions join now also cites `Blizzard_ProfessionsTemplates`, a sixth directory
outside this set.

### Recreate

Run from the repo root. It checks out the pinned commit, not the branch head: a plain
`--branch forever` clone lands on whatever Blizzard pushed last, and every `file:line` citation
in the docs would then point at a tree nobody pinned. The SHA is read from the table above, the
same way `bump.sh` reads it, so a re-pin edits one line.

```sh
SHA=$(grep -oE '\b[0-9a-f]{40}\b' vendor/PINS.md | head -1)
git clone --filter=blob:none --no-checkout --depth 1 --branch forever \
  https://github.com/Gethe/wow-ui-source.git vendor/wow-ui-source
cd vendor/wow-ui-source
git fetch --depth 1 origin "$SHA"
git sparse-checkout init --cone
git sparse-checkout set \
  Interface/AddOns/Blizzard_LegacySystem \
  Interface/AddOns/Blizzard_LegacyChallengeTracker \
  Interface/AddOns/Blizzard_APIDocumentationGenerated \
  Interface/AddOns/Blizzard_AchievementUI \
  Interface/AddOns/Blizzard_SharedXML \
  Interface/AddOns/Blizzard_SharedXMLBase \
  Interface/AddOns/Blizzard_SharedXMLGame \
  Interface/AddOns/Blizzard_FrameXML \
  Interface/AddOns/Blizzard_FrameXMLBase \
  Interface/AddOns/Blizzard_FrameXMLUtil \
  Interface/AddOns/Blizzard_Fonts_Shared \
  Interface/AddOns/Blizzard_UIParent \
  Interface/AddOns/Blizzard_UIParentPanelManager \
  Interface/AddOns/Blizzard_UIParentUtil \
  Interface/AddOns/Blizzard_UIPanelTemplates \
  Interface/AddOns/Blizzard_GameTooltip \
  Interface/AddOns/Blizzard_AddOnList
git checkout "$SHA"
git rev-parse HEAD   # must equal $SHA
```

The clone is shallow, so moving the pin means re-fetching rather than checking out an older
SHA. Update this file in the same commit as any re-pin, and say what changed underneath.
