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
- Challenge ranking (`Model/`). Closeness reads criterion quantities whenever `need > 1`, so a
  0/42000 reputation criterion is not scored as one step from done. Zero-point challenges are
  excluded. Challenges with no measurable criteria sort last, under a divider, rather than at 0%.
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
- Escape closes the window. It refreshes on open, on `ACHIEVEMENT_EARNED` and
  `CRITERIA_UPDATE` while open (coalesced to one rebuild per second), and defers a rebuild
  until combat ends.

## Versioning

SemVer `0.x.y` while Forever is in beta; `1.0.0` is the release that targets Forever's launch
build on 2026-11-04. The client build is not encoded in the version string. One addon version
is expected to outlive several beta builds, so each release entry names the build it was
verified against instead. `LegacyNext.toc` carries `## Version: @project-version@`, which the
packager replaces with the git tag at build time, so the tag is the version. The first upload
is tagged `v0.1.0`.

[Unreleased]: https://github.com/lxhwes/LegacyNext/commits/main
