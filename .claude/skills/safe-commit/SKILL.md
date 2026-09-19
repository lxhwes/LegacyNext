---
name: safe-commit
description: Run the project's gates and land a change as a small, well-scoped, conventional commit. Use this whenever you are about to commit or push anything in LegacyNext, when you have finished a piece of work and the tree is dirty, when the user says "commit this", "ship it" or "land it", and whenever another skill's workflow ends in a commit — beta-build-bump names it directly at the end of a re-pin. It runs luacheck and busted (the same two commands CI runs), plus the CLAUDE.md hard-constraint checks that no linter can express, checks nothing gitignored or unprovenanced is being staged, then writes a conventional-commit message. Never pushes without asking.
---

# Landing a change

Two things make committing here worth a skill rather than a reflex. CI runs exactly
`luacheck LegacyNext spec` and `busted`, so a skipped lint is not saved time — it is a red
build with a round trip attached. And the rules that matter most on this project are invisible
to both tools: a hardcoded achievement ID lints clean, passes every test, and breaks silently
when Blizzard renumbers it mid-beta.

## Run the gate

```sh
.claude/skills/safe-commit/scripts/precommit.sh            # whole tree
.claude/skills/safe-commit/scripts/precommit.sh --staged   # pattern checks on staged files only
```

It runs lint and tests, then checks the changed files for:

- **write APIs** — `ResetTree`, purchase, commit, staging. Read-only, always.
- **the filtered-achievement API** — global state shared with Blizzard's own UI, decided
  against in `docs/status.md`.
- **`LoadAddOn`** — `Blizzard_LegacySystem` is load-on-demand and we never load it.
- **client gating** — `WOW_PROJECT_ID`, `GetBuildInfo()`, interface-number comparisons. This
  client reports Mainline on interface 16001, so those tests give the wrong answer here.
- **bare 4+ digit literals**, as a heuristic for a hardcoded achievement, category or criteria
  ID. It warns rather than fails because constants and fallbacks are legitimate — read each hit
  and confirm.
- **layer violations** — a WoW global in `Model/`, `UI/` reaching into `Api/`.
- **staging mistakes** — anything under `tools/`, `.release/`, `vendor/` other than `PINS.md`,
  or `.claude/skill-evals/`.
- **fixtures with no provenance header**, which cannot later be told apart from an invention.
- **in-game scripts**, by handing `docs/ingame-commands.md` to `ingame-script`'s parse gate.

Exit codes: `0` clean, `1` a hard failure, `2` warnings worth reading, `3` the toolchain is
missing. On `3`, either build it (CLAUDE.md, Toolchain) or say plainly in your report that the
commit went in **unverified** — CI will run the checks either way, and a quiet skip means the
failure arrives attached to somebody else's next push.

A warning is not a rubber stamp. Read each one and either fix it or say why it is fine.

## Then read your own diff

The gate catches patterns. These need a reader:

- **Does a citation carry a pin stamp**, and does it match `vendor/PINS.md`? Line numbers are
  pin-relative, and a stale one still reads as verified.
- **Is anything marked `[verified]` that only an inference supports?** The tag is evidence, not
  confidence. If the client did not say it, it is `[unverified]`.
- **Did a test get asserted against a shape nobody captured?** Fabricated fixtures are the one
  thing CLAUDE.md forbids outright. A `pending` test naming its blocking command is the correct
  outcome, not a failure to finish.
- **Is the change one thing?** Small commits are a project convention. A vendor re-pin plus a
  ranking change is two commits — and the second one is what somebody will want to revert.
- **Did docs that should have moved, move?** A verified finding belongs in
  `docs/legacy-internals.md`; a client fact in `CLAUDE.md`; a phase or question state in
  `docs/status.md`. A finding that lives only in a commit message is lost.

## Write the message

Conventional commits, matching the vocabulary already in the log rather than inventing a new
one:

```sh
git log --oneline -15
```

Types in use: `feat`, `fix`, `docs`, `chore`. Scopes in use: `skills`, `ingame`, `legacy`,
`vendor`, `git`, `scaffold`. Subject in the imperative, no trailing period.

**Examples:**

Input: added the guarded reward-track read plus its stub and citation
Output: `feat(api): read reward track state behind the standard guard`

Input: captured criteria rows from the client and turned them into the first fixtures
Output: `feat(spec): add captured criteria fixtures for both progress shapes`

Input: re-pinned vendor to a newer beta build, nothing in our dirs moved
Output: `chore(vendor): re-pin forever branch to 1.60.2.70114`

Input: the flattened in-game script was losing everything after a comment
Output: `fix(ingame): make WoWLua scripts survive newline stripping`

The body earns its place when the *why* is not obvious from the diff — a constraint that forced
an unusual shape, a value that came back surprising, what stayed `pending` and why. Skip it
when the subject already says everything.

If the session's own instructions specify attribution trailers, append them as the last lines.
Do not put a model name anywhere else in the message, and do not put one in code comments, doc
prose, or a PR body — those are repository artifacts with a long life and the model that wrote
them is not a fact about the code.

## Stage deliberately, and ask before pushing

Stage by path, never `git add -A`: untracked noise is exactly what the staging check exists to
catch, and an unrelated file swept into a commit is the kind of thing that survives a review.

```sh
git status --porcelain
git add <paths>
git diff --cached --stat
```

**Never push without asking** (CLAUDE.md, Conventions), and never push to `main`. Ask once,
plainly, naming the branch. If the answer has already been given for this piece of work, that
answer holds — do not re-ask for every commit in a sequence you were told to land.

## Reporting it

Say what ran and what it said, in one or two lines. If lint or tests did not run, say that
first — an unqualified "committed" implies they passed, which is the one claim here that must
never be decoration.
