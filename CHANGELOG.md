# Changelog

All notable changes to LegacyNext are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the version numbers follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described under Versioning below.

LegacyNext targets the World of Warcraft: Forever beta. Every entry is verified against client
build 1.60.1 (69913), interface 16001, unless it says otherwise.

## [Unreleased]

### Added

- `/lgn` and `/legacynext` open the Next Up window: incomplete Legacy challenges ranked by
  closeness to completion. Each row shows the name, category, points awarded and criteria
  remaining. `/lgn help` lists the commands.
- Category filter over the game's own Legacy categories.
- Reward track header: current Legacy points, points to the next reward, and that reward's name.
- Challenge ranking (`Model/`) in three tiers, each under its own divider: in progress (sorted
  by closeness), not started (the game's category order), and no progress shown. Closeness
  reads criterion quantities whenever `need > 1`, so a 0/42000 reputation criterion is not
  scored as one step from done. Zero-point challenges are excluded. Challenges with no
  measurable criteria sit in the last tier rather than at 0%.
- Other classes' challenges are hidden for the current character, with a line saying how many.
  They are matched by structure against the character's class name, and nothing is hidden if
  that fails to match.
- Reward-track summary (`Model/`): current level, next threshold and reward name from the
  sparse renown level list.
- Guarded client read layer (`Api/`). Every call is feature-detected, `pcall`ed and checked with
  `issecretvalue`, and returns plain tables or `nil` plus a reason. Covers challenges, the
  reward track, tree spend and character state. A struct with one uncopyable field is kept
  and the field named, rather than dropped whole.
- `/lgn probe`: one line per client API reporting `ok`, `nil`, `missing`, `error`, `secret` or
  `skipped`.
- `/lgn dump [section] [page]`: a copyable Lua literal of everything `Api/` returns, shown in a
  window you can select from. Sections: `all`, `summary`, `challenges`, `categories`, `rewards`,
  `trees`, `character`, `probe`.
- `/lgn uidump [category]`: the window's contents as text, for checking what would render
  without a screenshot.
- Addon icon in the AddOns list (`Media/icon.tga`, original art; see `docs/icon-design.md`).
- Escape closes the window. It refreshes on open, on `ACHIEVEMENT_EARNED` within a second and
  on `CRITERIA_UPDATE` at most every five seconds while open, and defers any rebuild,
  including the first on open, until combat ends. A read that throws shows as the window's
  error state instead of a Lua error.

## Versioning

SemVer `0.x.y` while Forever is in beta; `1.0.0` is the release that targets Forever's launch
build on 2026-11-04. The client build is not encoded in the version string. One addon version
is expected to outlive several beta builds, so each release entry names the build it was
verified against instead. `LegacyNext.toc` should carry `## Version: @project-version@`, which
the packager replaces with the git tag at build time, so the tag is the version. The TOC still
reads `0.0.1`; the first release changes it. The first upload is tagged `v0.1.0`.

[Unreleased]: https://github.com/lxhwes/LegacyNext/commits/main
