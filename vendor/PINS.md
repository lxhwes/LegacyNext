# Vendored reference pins

Read-only Blizzard UI source. Nothing here is shipped, imported, or copied into the addon —
it exists so API behavior can be checked against the forever branch instead of assumed from
retail. The checkout itself is gitignored; this file is the record.

## wow-ui-source

| | |
|---|---|
| Remote | https://github.com/Gethe/wow-ui-source.git |
| Branch | `forever` |
| Commit | `bd2470aed543f72697a044e989285b6c83e63f73` |
| `version.txt` | `1.60.1.70009` |
| Pinned on | 2026-09-26 (was `70ef1b2`, `1.60.1.69913`, 2026-09-18) |

Sparse checkout (cone mode) covers only:

```
Interface/AddOns/Blizzard_LegacySystem
Interface/AddOns/Blizzard_LegacyChallengeTracker
Interface/AddOns/Blizzard_APIDocumentationGenerated
Interface/AddOns/Blizzard_AchievementUI
version.txt
```

All four directories were present at this commit, and at `bd2470a`.

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
`bd2470a`, checked directory by directory on 2026-09-26.

Four directories cited across the docs are still outside this set: `Blizzard_MicroMenu` and
`Blizzard_SharedTalentUI` (`docs/legacy-internals.md`), `Blizzard_MajorFactions`
(`docs/legacy-internals.md`, toast events) and `Blizzard_Professions` (`CLAUDE.md`,
`docs/status.md`). `Blizzard_FrameXML` and `Blizzard_FrameXMLBase` were on this list until the
widening above brought them in. They were read by running `git sparse-checkout set Interface`
at this same SHA — 53 MB, 4405 files — and then narrowing back. Widen the same way to re-check
them; the pin does not move.

### Recreate

```sh
git clone --filter=blob:none --no-checkout --depth 1 --branch forever \
  https://github.com/Gethe/wow-ui-source.git vendor/wow-ui-source
cd vendor/wow-ui-source
git sparse-checkout init --cone
git sparse-checkout set \
  Interface/AddOns/Blizzard_LegacySystem \
  Interface/AddOns/Blizzard_LegacyChallengeTracker \
  Interface/AddOns/Blizzard_APIDocumentationGenerated \
  Interface/AddOns/Blizzard_AchievementUI
git checkout
git sparse-checkout add <every path in the "Widened on 2026-09-19" list above>
```

The clone is shallow, so moving the pin means re-fetching rather than checking out an older
SHA. Update this file in the same commit as any re-pin, and say what changed underneath.
