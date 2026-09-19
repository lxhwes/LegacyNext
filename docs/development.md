# Development

How to get a working checkout, run the checks, and get data back out of the game. Scope,
constraints and the Legacy API surface are in `CLAUDE.md`. Current position is in
`docs/status.md`.

## Bootstrap on a new machine

Two directories the repo needs are **gitignored on purpose** — the vendored Blizzard source
and the Lua toolchain. Neither is in the clone. Recreate both:

**1. Vendored reference source.** Read-only, never imported, pinned in `vendor/PINS.md` —
that file is the source of truth for the SHA, check it before trusting the command below.
The command below is the minimum. After it, run `git sparse-checkout add` with the full list
in `vendor/PINS.md` (the original four plus the 2026-09-19 widening); the citations in
`LegacyNext/UI/` and `docs/ui-templates.md` resolve only with the widened set.

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

**2. Lua 5.1 toolchain.** Homebrew has no `lua@5.1` formula, so this builds PUC Lua 5.1.5
locally with hererocks. Takes a couple of minutes.

```sh
python3 -m venv tools/venv
tools/venv/bin/pip install hererocks
tools/venv/bin/hererocks tools/lua51 --lua 5.1 --luarocks latest
./tools/lua51/bin/luarocks install --no-doc busted
./tools/lua51/bin/luarocks install --no-doc luacheck
```

**3. Verify.**

```sh
./tools/lua51/bin/luacheck LegacyNext spec
./tools/lua51/bin/busted
```

Expect zero warnings and a green suite. CI does the same thing on Lua 5.1 via
`leafo/gh-actions-lua`.

## Layout

| Path | What lives there |
|---|---|
| `LegacyNext/` | The addon. `Api/` `Model/` `UI/` `Store/` `Debug/` — layering rules in `CLAUDE.md` |
| `spec/` | busted tests, `fixtures/` captured from the live client, `stubs/` for `Api/` |
| `docs/` | Research and status — see below |
| `vendor/` | Pinned Blizzard source, gitignored except `PINS.md` |
| `tools/` | Local Lua toolchain, gitignored |

## Docs

| File | What it's for |
|---|---|
| `CLAUDE.md` | Scope, hard constraints, verified client facts, conventions |
| `docs/status.md` | Where we are, what's next, what's still unanswered |
| `docs/legacy-internals.md` | How Blizzard's Legacy system works, with `file:line` citations |
| `docs/ingame-commands.md` | Commands to run on the beta, and what each one answers |
| `docs/beta-builds.md` | What changed per re-pin of the vendored source |
| `docs/distribution.md` | Packaging: what the packager dry-run showed, and what is still unverified |
| `docs/ui-templates.md` | Which frame templates, fonts and FontString methods exist on the Forever branch, with citations |
| `docs/icon-design.md` | The addon icon: the decision, the concepts, and the steps to ship it |
| `docs/icon-drafts/` | Icon SVG source, rendered PNGs, and the render scripts |

## Working on this

The addon cannot be run outside the game and SavedVariables are broken on the beta, so
anything needing live data comes back through a slash command — see `docs/ingame-commands.md`.
Captured output becomes a fixture in `spec/fixtures/`; we never invent a response shape.

Three commands exist for that:

| Command | What it gives you |
|---|---|
| `/lgn probe` | One chat line per API: `ok`, `partial`, `nil`, `missing`, `error`, `secret` or `skipped` |
| `/lgn dump [section] [page]` | A copyable `return { ... }` literal. Sections: `all`, `summary`, `challenges`, `categories`, `rewards`, `trees`, `character`, `probe` |
| `/lgn uidump [category]` | What the window would show, as text: header lines, filter bar with counts, every row, the state line and the names that overflow the row. Compare it to `spec/golden/uidump_combined.txt` |

`/lgn dump challenges` is paged 20 at a time. Every dump is pure data with no comment lines, so
it still parses if a paste path strips the newlines.

## Installing a development copy

Copy or symlink `LegacyNext/` (the inner folder, the one holding `LegacyNext.toc`) into
`_classic_beta_/Interface/AddOns/`. Type `/reload` after any change; `ReloadUI()` is protected
on this client so it cannot be called from a script.
