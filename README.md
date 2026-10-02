<p align="center">
  <img src="https://raw.githubusercontent.com/lxhwes/LegacyNext/main/docs/icon-drafts/almost-full-256.png" width="120" alt="LegacyNext">
</p>

<h1 align="center">LegacyNext</h1>

<p align="center"><b>Which Legacy challenge is closest to done.</b></p>

<p align="center">
  <a href="https://github.com/lxhwes/LegacyNext/actions/workflows/ci.yml"><img src="https://github.com/lxhwes/LegacyNext/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/lxhwes/LegacyNext/releases"><img src="https://img.shields.io/github/v/release/lxhwes/LegacyNext?include_prereleases&label=release&style=flat-square&labelColor=1B2740&color=4A5878" alt="Latest release"></a>
  <a href="https://www.curseforge.com/wow/addons/legacynext"><img src="https://img.shields.io/badge/CurseForge-LegacyNext-F2B33D?style=flat-square&labelColor=1B2740" alt="LegacyNext on CurseForge"></a>
  <img src="https://img.shields.io/badge/WoW%3A%20Forever-1.60.1%20beta-F2B33D?style=flat-square&labelColor=1B2740" alt="WoW: Forever 1.60.1 beta">
  <img src="https://img.shields.io/badge/Interface-16001-FFD98A?style=flat-square&labelColor=1B2740" alt="Interface 16001">
  <a href="https://github.com/lxhwes/LegacyNext/blob/main/LICENSE"><img src="https://img.shields.io/badge/licence-MIT-F2B33D?style=flat-square&labelColor=1B2740" alt="MIT licence"></a>
</p>

Shows which of your Legacy challenges in World of Warcraft: Forever are closest to done.
Open it and the challenges you have started are listed closest-first, with your reward track
at the top. A second tab lists your characters and which of them is closest to each
tradeskill challenge.

## What it does

- Lists your incomplete Legacy challenges in three groups: started ones sorted by how close
  each is to completion, then ones you have not started, then the ones the game reports no
  progress for. Each row shows the name, what is left ("3/6", "0/150") and the points it
  awards. Hover a row for its category, description and every criterion.
- Leaves out the other classes' challenges, which your current character can never earn, and
  says how many it left out.
- Filters the list by the game's own Legacy categories.
- Shows your reward track: current Legacy points, points to the next reward, and that reward's
  name.
- Remembers every character you log in with: class, level, professions, and Legacy points
  spent per tree and unspent. The Roster tab lists them, then each tradeskill challenge one of
  them has the profession for, closest character first.

## The window

Layout of the Next Up tab, with the numbers a fresh Shaman sees:

```
  Next Up  Roster
┌──────────────────────────────────────────────────────────┐
│ Legacy Track  ·  0 pts  ·  15 to next                    │
│ Next: Replica Ironforge Air Rifle                        │
├──────────────────────────────────────────────────────────┤
│ [All (41)]  Classes (3)  Tradeskills (18)  Dungeons (3)  │
│ Raids (3)  Player vs. Player (12)  Adventure (2)         │
├──────────────────────────────────────────────────────────┤
│ ───────────────────── not started ────────────────────── │
│ Journeyman Alchemist                          0/150  1pt │
│ Expert Alchemist                              0/225  1pt │
│ Novice Spelunker                                0/6  1pt │
│ Master of Alterac Valley                    0/42000  1pt │
│ ────────────────── no progress shown ─────────────────── │
│ Novice Shaman                                        1pt │
│ Rank 3                                               1pt │
│ 24 other-class challenges hidden                         │
└──────────────────────────────────────────────────────────┘
```

Each row is one line of text with the challenge's icon, under a divider for its group. A fresh
character starts with nothing in progress, so the list opens at "not started". Those rows stay
in the game's own category order, because zero progress says nothing about which is closest.
The "no progress shown" divider matters too. Those challenges expose no progress at all
through the game's API, so they sit below it rather than being drawn as 0%.

The window keeps its tab, filter, position and size for each character. Drag the bottom-right
corner to resize it.

Click a challenge row to open Blizzard's Legacy panel on that challenge. Shift-click it to put
its link in the chat box. Blizzard's panel only opens once the account has earned a Legacy
point, and neither works in combat.

## Commands

| Command | What it does |
|---|---|
| `/lgn` or `/legacynext` | Open or close the window. Escape closes it |
| `/lgn show` / `/lgn hide` | The same, without the toggle |
| `/lgn help` | List every command |
| `/lgn minimap` | Show or hide the minimap button |
| `/lgn config` | Open LegacyNext's settings |
| `/lgn roster` | The Roster tab's data as copyable text |
| `/lgn roster forget <Name-Realm>` | Remove a deleted character from the roster |
| `/lgn uidump [category]` | What the Next Up tab would show, as copyable text. `/lgn uidump roster` does the same for the Roster tab |
| `/lgn probe` | One line per API call: ok, partial, nil, missing, error, secret, skipped |
| `/lgn dump [section] [page]` | Everything the addon reads, as a Lua literal |

The window also opens from LegacyNext's minimap button, from the minimap's addon dropdown (the
small numbered button under the calendar), and from a key binding under Key Bindings > AddOns.
Left-click the minimap button to open the window and right-click it for settings. Drag it round
the minimap's edge to move it. Its tooltip shows the reward track, your unspent points and the
three challenges closest to done. Esc > Options > AddOns > LegacyNext hides or locks it. The dropdown lists only addons
enabled for all characters, so if LegacyNext is missing there, check the character dropdown in
the AddOns list.

`uidump`, `probe` and `dump` are for bug reports. Paste their output into an issue and it says
exactly what the client handed back.

## What it does not do

- No build planner. Wowhead and wowforeverbuilds.com already have calculators for the trees.
- Nothing combat-related.
- No Hardcore. Hardcore's Legacy challenges and perks are separate and launch later.
- It never touches your Legacy trees. LegacyNext only reads. It never calls a purchase, reset or
  commit API, so it cannot spend, refund or move a point.

## Installing

Install it from [CurseForge](https://www.curseforge.com/wow/addons/legacynext), or download the
zip from [GitHub Releases](https://github.com/lxhwes/LegacyNext/releases) and unzip it into
the AddOns folder. The beta client lives in `_classic_beta_`, so the folder is

    World of Warcraft/_classic_beta_/Interface/AddOns/LegacyNext/

`LegacyNext.toc` must sit directly inside that folder. If the addon is missing from the
in-game AddOns list, check that it went under `_classic_beta_` and not `_retail_` or
`_classic_`. Once Forever launches the folder name will change; this file will say so.

## Known limitations

- This is a beta client. Blizzard's challenge, category and criteria IDs change between builds.
  LegacyNext hardcodes none of them, but a new build can still change what the game reports.
  Verified against build 1.60.1 (70170).
- The roster knows a character only once it has logged in with LegacyNext enabled.
- 34 challenges expose no progress through the game's API: class levelling, the PvP ranks and a
  few others. They sit under a "no progress shown" divider instead of being scored as 0%.
- Other classes' challenges are recognised by matching your class name against the game's
  category names. If that ever fails to match, nothing is hidden.
- The list refreshes when you open the window, within a second of earning an achievement, and
  at most every five seconds while criteria progress. It waits until you leave combat before
  rebuilding.

## Roadmap

| | Version | What |
|---|---|---|
| ▰▰▰▰ | **v0 "Next Up"** | The ranked list, category filter and reward track above. Released in 0.1.0-beta1 |
| ▰▰▰▱ | **v1 "Roster"** | A snapshot of each character, a view of every alt, and a match from profession challenge to alt ("your Alchemist is 20 skill from this"). Released in 0.1.0-beta1. Next: keying characters by their GUID, so a name change between builds no longer splits one character into two rows. Class-levelling challenges get no match, because the game doesn't tell addons what level each one needs |

Changes are listed in [CHANGELOG.md](https://github.com/lxhwes/LegacyNext/blob/main/CHANGELOG.md).

## Bugs and requests

Open an issue at https://github.com/lxhwes/LegacyNext/issues with your client build and the
challenge name. Contributors: setup, tests and the in-game data workflow are in
[docs/development.md](https://github.com/lxhwes/LegacyNext/blob/main/docs/development.md).

## Licence

MIT. See [LICENSE](https://github.com/lxhwes/LegacyNext/blob/main/LICENSE).

World of Warcraft is a trademark of Blizzard Entertainment. LegacyNext is a fan-made addon,
not affiliated with or endorsed by Blizzard.
