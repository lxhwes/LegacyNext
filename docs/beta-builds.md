# Forever beta build log

What changed underneath us, per re-pin of `vendor/wow-ui-source`. Newest first.

Written by the `beta-build-bump` skill, which runs whenever Blizzard pushes a beta build.
"Touches us" means the Legacy API surface LegacyNext actually calls — see
`.claude/skills/beta-build-bump/references/watchlist.txt` for the list. A build that moved
only `version.txt` gets an entry too; knowing a build was boring is worth recording, and a
gap in this file should mean "nobody checked", not "nothing happened".

Beta opened 2026-09-17. Launch is 2026-11-04.

## 1.60.1.69913 — 2026-09-18

Pin: initial → `70ef1b2`

Baseline entry, recorded when the skill was written rather than by a bump. This is the
commit `vendor/PINS.md` has always pointed at.

**Does not touch us**

The four builds preceding this one on the mirror (`69876`, `69893`, `69876`, `69893`) changed
nothing in `Blizzard_LegacySystem`, `Blizzard_LegacyChallengeTracker`,
`Blizzard_APIDocumentationGenerated`, or `Blizzard_AchievementUI`. Only `version.txt` moved.

**Worth knowing**

Build numbers on this mirror are not monotonic — the sequence above goes forwards, backwards,
then forwards again, because commits get re-pushed out of order. Newest commit does not mean
highest build. The skill flags this as `BUILD_WENT_BACKWARDS` rather than guessing.

All six values in CLAUDE.md's Legacy constants table were confirmed against
`Blizzard_APIDocumentationGenerated/LegacyConstantsDocumentation.lua` at this commit.
