# Vendored reference pins

Read-only Blizzard UI source. Nothing here is shipped, imported, or copied into the addon —
it exists so API behavior can be checked against the forever branch instead of assumed from
retail. The checkout itself is gitignored; this file is the record.

## wow-ui-source

| | |
|---|---|
| Remote | https://github.com/Gethe/wow-ui-source.git |
| Branch | `forever` |
| Commit | `70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e` |
| `version.txt` | `1.60.1.69913` |
| Pinned on | 2026-09-18 |

Sparse checkout (cone mode) covers only:

```
Interface/AddOns/Blizzard_LegacySystem
Interface/AddOns/Blizzard_LegacyChallengeTracker
Interface/AddOns/Blizzard_APIDocumentationGenerated
Interface/AddOns/Blizzard_AchievementUI
version.txt
```

All four directories were present at this commit.

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
```

The clone is shallow, so moving the pin means re-fetching rather than checking out an older
SHA. Update this file in the same commit as any re-pin, and say what changed underneath.
