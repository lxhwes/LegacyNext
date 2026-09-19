<p align="center">
  <img src="https://raw.githubusercontent.com/lxhwes/LegacyNext/main/docs/icon-drafts/almost-full-256.png" width="120" alt="LegacyNext">
</p>

<h1 align="center">LegacyNext</h1>

<p align="center"><b>Which Legacy challenge is closest to done.</b></p>

<p align="center">
  <a href="https://github.com/lxhwes/LegacyNext/actions/workflows/ci.yml"><img src="https://github.com/lxhwes/LegacyNext/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/WoW%3A%20Forever-1.60.1%20beta-F2B33D?style=flat-square&labelColor=1B2740" alt="WoW: Forever 1.60.1 beta">
  <img src="https://img.shields.io/badge/Interface-16001-FFD98A?style=flat-square&labelColor=1B2740" alt="Interface 16001">
  <img src="https://img.shields.io/badge/Lua-5.1-4A5878?style=flat-square&labelColor=1B2740" alt="Lua 5.1">
  <img src="https://img.shields.io/badge/status-v0%20in%20development-4A5878?style=flat-square&labelColor=1B2740" alt="Status: v0 in development">
  <a href="https://github.com/lxhwes/LegacyNext/blob/main/LICENSE"><img src="https://img.shields.io/badge/licence-MIT-F2B33D?style=flat-square&labelColor=1B2740" alt="MIT licence"></a>
</p>

Shows which of your Legacy challenges in World of Warcraft: Forever are closest to done.
Open it and every incomplete challenge is listed nearest-first, with your reward track at the top.

## What it does

- Lists your incomplete Legacy challenges sorted by how close each one is to completion. Each
  row shows the name, what is left ("3/6", "0/150") and the points it awards. Hover a row for
  its category, description and every criterion.
- Filters the list by the game's own Legacy categories.
- Shows your reward track: current Legacy points, points to the next reward, and that reward's
  name.

## The window

Layout, with the numbers a fresh character sees:

```
┌────────────────────────────────────────┐
│ Legacy Track  ·  0 pts  ·  15 to next  │
│ Next: Replica Ironforge Air Rifle      │
├────────────────────────────────────────┤
│ [All] Class Prof PvP Rep Dung Raid     │
├────────────────────────────────────────┤
│ Journeyman Alchemist        0/150  1pt │
│ Novice Spelunker              0/6  1pt │
│ Master of Alterac Valley  0/42000  1pt │
│ Conquerer of the Deeps        0/8  1pt │
│ Expert Alchemist            0/225  1pt │
│ ─────────── no progress shown ──────── │
│ Novice Druid                       1pt │
│ Rank 3                             1pt │
└────────────────────────────────────────┘
```

Rows are text, one line each. The divider is not decoration: 34 challenges expose no progress
at all through the game's API, so they sit below it rather than being drawn as 0%.

## Commands

| Command | What it does |
|---|---|
| `/lgn` or `/legacynext` | Open or close the Next Up window. Escape closes it |
| `/lgn show` / `/lgn hide` | The same, without the toggle |
| `/lgn help` | List every command |
| `/lgn uidump [category]` | What the window would show, as copyable text |
| `/lgn probe` | One line per API call: ok, partial, nil, missing, error, secret, skipped |
| `/lgn dump [section] [page]` | Everything the addon reads, as a Lua literal |

The last three are for bug reports. Paste their output into an issue and it says exactly what
the client handed back.

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

| | Version | What |
|---|---|---|
| ▰▰▰▱ | **v0 "Next Up"** | The ranked list, category filter and reward track above |
| ▱▱▱▱ | v1 "Roster" | Once SavedVariables work: a snapshot of each character on login and logout (class, level, professions, points spent per tree, unspent points), a view of every alt, and a match from challenge to alt for class-levelling and profession challenges ("your level 34 Druid is 6 levels from this") |

Changes are listed in [CHANGELOG.md](https://github.com/lxhwes/LegacyNext/blob/main/CHANGELOG.md).

## Bugs and requests

Open an issue at https://github.com/lxhwes/LegacyNext/issues with your client build and the
challenge name. Contributors: setup, tests and the in-game data workflow are in
[docs/development.md](https://github.com/lxhwes/LegacyNext/blob/main/docs/development.md).

## Licence

MIT. See [LICENSE](https://github.com/lxhwes/LegacyNext/blob/main/LICENSE).
