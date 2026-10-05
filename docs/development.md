# Development

How to get a working checkout, run the checks, and get data back out of the game. Scope,
constraints and the Legacy API surface are in `CLAUDE.md`. Current position is in
`docs/status.md`.

## Bootstrap on a new machine

Two directories the repo needs are **gitignored on purpose** — the vendored Blizzard source
and the Lua toolchain. Neither is in the clone. Recreate both:

**1. Blizzard reference source.** Read-only, never imported, and shared with GuildCrafts, so
it lives outside this repo: a directory holding `PINS.md`, `consumers.txt` and a sparse
`wow-ui-source/` clone, found through `$WOW_FOREVER_SRC` (default
`~/code/wow-ui-source-forever`). Run the "Recreate" block at the end of that `PINS.md` from that
directory. It is kept only there so the SHA and the directory list cannot drift between two
copies, and it checks out the pinned commit rather than the branch head. It ends with
`git rev-parse HEAD`, which must match the SHA in the PINS.md table. The scripts below come
from the `forever-tools` Claude Code plugin and are on `PATH` in a session where it is enabled.

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
| `spec/` | busted tests, `fixtures/` captured from the live client, `golden/` for the uidump text. `stubs/` holds only a README, reserved for a fixture-driven stub environment |
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

The addon cannot be run outside the game, so anything needing live data comes back through a
slash command. The queue of open questions for the live client is `docs/ingame-commands.md`.
Captured output becomes a fixture in `spec/fixtures/`; we never invent a response shape.

Four commands exist for that:

| Command | What it gives you |
|---|---|
| `/lgn probe` | One chat line per API: `ok`, `partial`, `nil`, `missing`, `error`, `secret` or `skipped` |
| `/lgn dump [section] [page]` | A copyable `return { ... }` literal. Sections: `all`, `summary`, `challenges`, `categories`, `rewards`, `trees`, `character`, `probe` |
| `/lgn uidump [category]` | What the Next Up tab would show, as text: header lines, filter bar with counts, every row, the state line and the names that overflow the row. Compare it to `spec/golden/uidump_combined.txt`. `/lgn uidump roster` renders the Roster tab; compare it to `spec/golden/uidump_roster.txt` |
| `/lgn roster` | v1's stored characters and tradeskill candidates as text. The `== STORE ==` line records what came back from disk this session, and `== RAW ==` is the fixture. `/lgn roster forget <Name-Realm>` drops an alt |

`/lgn dump challenges` is paged 20 at a time. Every dump is pure data with no comment lines, so
it still parses if a paste path strips the newlines.

## Workflows

The scripts live under `.claude/skills/`, since the Claude Code skills drive them, but they
are plain scripts and run by hand the same way.

**A paste from the game becomes a fixture.** Never hand-edit the data. The script keeps the raw
text verbatim and refuses to write without provenance:

```sh
.claude/skills/fixture-intake/scripts/dump_to_fixture.py PASTE --out spec/fixtures/NAME.lua \
  --source "<queue ID>, docs/ingame-commands.md" --date YYYY-MM-DD \
  --build 1.60.1.NNNNN --pin <short sha> --character "<who, what state>"
```

`/lgn dump` output is already a `return { ... }` literal. It goes into `spec/fixtures/` with a
provenance header, following `spec/fixtures/README.md`.

**An in-game script is parse-checked before anyone runs it in the client.** This covers both the multi-line form
and a copy with the newlines stripped:

```sh
forever-check-script docs/ingame-commands.md
```

**The uidump output changes on purpose.** When a `Model` or `Debug.RenderView` change is meant
to alter row content, regenerate the golden file, then read the diff before committing it:

```sh
UPDATE_GOLDEN=1 ./tools/lua51/bin/busted spec/debug/uidump_spec.lua
git diff spec/golden/
```

A golden diff you did not intend is a bug, not a file to regenerate.

**Blizzard pushes a beta build.** Check first, then apply. The check never touches the checkout:

```sh
forever-bump               # writes a diff summary, triaged for every consumer of the pin
forever-bump --apply <sha> # moves the shared checkout, then re-checks this repo's citations
forever-bump --reconcile   # after GuildCrafts moved the pin: catch this repo up
```

Commit the shared `PINS.md` in its own directory. Here, record the result in
`docs/beta-builds.md`, run `forever-env --mark-reconciled`, and commit both together.

**Citations after a bump.** Every `path:line` in the docs is pin-relative:

```sh
forever-verify-citations --expect-symbol docs/legacy-internals.md docs/ui-templates.md
```

It resolves `.lua` citations only. The `.xml` ones in `docs/ui-templates.md` are checked by
hand.

## Installing a development copy

Copy or symlink `LegacyNext/` (the inner folder, the one holding `LegacyNext.toc`) into
`_classic_beta_/Interface/AddOns/`. Type `/reload` after any change; `ReloadUI()` is protected
on this client so it cannot be called from a script.

## Pull requests

CI runs the lint and the suite on every push and pull request, and both must pass. Commits use
conventional-commit subjects (`fix(model): ...`), with a test before the code it covers. Read
the hard constraints in `CLAUDE.md` before touching `Api/`: the addon only reads, and never
hardcodes an achievement, category or criteria ID.
