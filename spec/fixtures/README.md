# Fixtures

Captured client data only. Every file here comes from `/legacynext dump` pasted out of the
game, never from a shape we guessed at.

If a test needs a shape no fixture covers, write the test as `pending` and leave it. A
fabricated fixture is worse than a missing one: achievement IDs, category IDs, and criteria
will churn through beta, and Forever's API docs already differ from live retail 12.1.0 by
about 6k lines.

Name files after what produced them, e.g. `getachievementcriteriainfo_dungeons.lua`.

## The one carve-out — derived progress values, 2026-09-19

`Model/` tests may take a **captured** challenge and vary only a numeric progress field
(`have`, `completed`) to exercise ordering. Every captured point-bearing criterion reads
`have = 0`, so partial progress beating untouched — the case Next Up exists for — cannot be
tested from real data yet.

The line this does not cross: **the shape stays exactly as captured**. No invented field, no
invented `criteriaType`, no guessed struct. Only a number moves, in a table whose every key
came from the client.

Rules for using it:

- Mark it in the file, at the value: `-- derived: captured 0, varied to test ordering`
- Only in `Model/` tests, never in an `Api/` fixture or a `spec/stubs/` return
- Keep **C3** open until a real mid-progress point-bearing capture replaces them

A derived value is a stand-in with a receipt. An invented shape is a lie that compiles.
