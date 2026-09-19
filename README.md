# LegacyNext

Shows which of your Legacy challenges in World of Warcraft: Forever are closest to done.
Open it and every incomplete challenge is listed nearest-first, with your reward track at the top.

## What it does

- Lists your incomplete Legacy challenges sorted by how close each one is to completion. Each
  row shows the name, its category, the points it awards, and what is left ("3/5 dungeons",
  "0/150 Alchemy").
- Filters the list by the game's own Legacy categories.
- Shows your reward track: current Legacy points, points to the next reward, and that reward's
  name.

## Opening it

Type `/lgn` or `/legacynext`. It opens a standalone window. `/lgn help` lists every command.

## What it does not do

- No build planner. Wowhead and wowforeverbuilds.com already have calculators for the trees.
- Nothing combat-related.
- No Hardcore. Hardcore's Legacy challenges and perks are separate and launch later.
- It never touches your Legacy trees. LegacyNext only reads. It never calls a purchase, reset or
  commit API, so it cannot spend, refund or move a point.

## Installing on the Forever beta

The beta client lives in `_classic_beta_`, so the addon folder is

    World of Warcraft/_classic_beta_/Interface/AddOns/LegacyNext/

`LegacyNext.toc` must sit directly inside that folder. If the addon is missing from the
in-game AddOns list, check that it went under `_classic_beta_` and not `_retail_` or
`_classic_`. Once Forever launches the folder name will change; this file will say so.

## Known limitations

- This is a beta client. Blizzard's challenge, category and criteria IDs change between builds.
  LegacyNext hardcodes none of them, but a new build can still change what the game reports.
  Verified against build 1.60.1 (69913).
- Nothing is saved between sessions. SavedVariables are written but never loaded back on the
  beta (a Blizzard-side bug), so v0 keeps no data of its own.
- 34 challenges expose no progress through the game's API: class levelling, the PvP ranks and a
  few others. They sit under a "no progress shown" divider instead of being scored as 0%.
- The list refreshes when you open the window and when the game reports achievement or
  criteria progress while it is open. It waits until you leave combat before rebuilding.

## Roadmap

v1 "Roster": once SavedVariables work, a snapshot of each character on login and logout (class,
level, professions, points spent per tree, unspent points), a view of every alt, and a match
from challenge to alt for class-levelling and profession challenges ("your level 34 Druid is 6
levels from this").

## Bugs and requests

Open an issue at https://github.com/lxhwes/LegacyNext/issues with your client build and the
challenge name. Contributors: setup, tests and the in-game data workflow are in
[docs/development.md](https://github.com/lxhwes/LegacyNext/blob/main/docs/development.md).

## Licence

MIT. See [LICENSE](https://github.com/lxhwes/LegacyNext/blob/main/LICENSE).
