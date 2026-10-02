# Contributing to LegacyNext

Thanks for helping. LegacyNext is a small addon kept by one person, so this is short.

## Reporting a bug

Use the bug report form on the [issues page](https://github.com/lxhwes/LegacyNext/issues/new/choose).
The most useful thing you can attach is the output of `/lgn dump summary`. It opens a
copyable box, and its `meta` block records your client build and addon version. If the list
looks wrong, add `/lgn uidump` too, which shows exactly what the window drew.

The beta changes between builds. A bug report without a build number often can't be
reproduced.

## Asking for a feature

Read [What it does not do](../README.md#what-it-does-not-do) first. LegacyNext will not get a
tree planner, anything combat-related, Hardcore support, or anything that spends, resets or
moves Legacy points. It only reads.

## Changing code

Setup, the toolchain and the in-game data workflow are in
[docs/development.md](../docs/development.md). The hard constraints are in
[CLAUDE.md](../CLAUDE.md). Read them before touching `LegacyNext/Api/`.

The rules that most often catch a first pull request:

- `luacheck LegacyNext spec` and `busted` must both pass. CI runs the same two commands.
- WoW globals are called only from `LegacyNext/Api/`. `Model/` is plain Lua and is where the
  tests live.
- Test fixtures are captured from the live client with `/lgn dump`. Never write one by hand.
  If a test needs a response shape nobody has captured yet, mark it `pending`.
- No achievement, category or criteria IDs in code. They change between beta builds.
- No external libraries (Ace3, LibStub and so on) without asking in an issue first.
- Commit subjects use [Conventional Commits](https://www.conventionalcommits.org/):
  `fix(model): ...`, `feat(ui): ...`.
- Add a line under `[Unreleased]` in [CHANGELOG.md](../CHANGELOG.md) for anything a player
  would notice.

The maintainer checks changes in the beta client before release. A pull request that needs
that check can sit for a few days, depending on when the game is next open.

## Licence

Contributions are accepted under the project's [MIT licence](../LICENSE).
