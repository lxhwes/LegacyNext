# The two dump shapes

A paste arrives in one of two forms, and they need opposite handling. Deciding which you have
is the first step of any intake — treating one as the other is how a capture gets mangled or
needlessly hand-transcribed.

| | **Lua literal** | **Semicolon rows** |
|---|---|---|
| Produced by | `/lgn dump [section]` (`Debug/`) | the ad-hoc WoWLua scripts in `docs/ingame-commands.md` |
| Looks like | `return { meta = {...}, challenges = {...} }` | `== SECTION ==` then `col;col;col` then rows |
| Intake | save it, add provenance, done | run `dump_to_fixture.py` |
| Typing | exact — it is already Lua | inferred from text, and lossy |

**Prefer `/lgn dump`.** CLAUDE.md now says so directly: it and `/lgn probe` do this properly,
and a new ad-hoc script is only for something the addon does not read yet. The reason is in the
table above — the literal needs no parser, so nothing can be lost or guessed between the client
and the fixture.

## Shape 1 — the Lua literal

`Debug.Build` (`LegacyNext/Debug/Debug.lua:212`) serializes `Api` output into one returned
table. Its design choices are load-bearing for intake:

- **Everything is data inside one table. No comment lines.** A dump that loses its newlines on
  the way back still parses; `--` headers would swallow the rest, the same flattening failure
  that shapes every in-game script. Do not "helpfully" add comments inside the returned table
  when editing the dumper.
- **Pipes are re-encoded and `%q` newlines normalised** (line ~28), so the result is a single
  clean Lua literal that round-trips back to the original string. This is *not* the lossy
  `|`→`!` substitution the old scripts use — here the original string survives.
- **Keys are sorted, identifiers rendered bare, reserved words bracketed.** Diffs between two
  dumps are therefore meaningful; keep it that way.
- **`meta` carries the provenance already** — section, client info, and for challenges the
  count and paging. That is the metadata `dump_to_fixture.py` has to be told by hand.
- **Sections exist because the copy truncates.** `all`, `summary`, `challenges`, `rewards`,
  `trees`, `character`, `probe`, with challenges paged 20 at a time and a nudge past 60k
  characters. A partial paste is the failure mode to watch for: check the closing brace is
  there before treating a dump as complete.

Intake for this shape is short: save the text as `spec/fixtures/<name>.lua`, prepend the
provenance comment header, confirm it loads, and note which section and page it was. Do not run
it through the converter — parsing a Lua literal back out of Lua text is pure loss.

What the fixture still needs on top of `meta`: **who ran it and on what character state**, in
the words a later reader needs ("fresh level 1, no points spent" versus "68 warrior, 9 points
in two trees"). `meta` knows the build; it does not know that.

## Shape 2 — semicolon rows

Still what sections B and C of `docs/ingame-commands.md` emit, and still what you get from any
new ad-hoc script. `dump_to_fixture.py` exists for exactly this.

```
== SECTION NAME ==
col1;col2;col3
value;value;value

== ANOTHER SECTION ==
key=value
key=value  otherKey=value
```

| Rule | Why |
|---|---|
| Sections open with `== NAME ==` alone on a line | The only unambiguous delimiter in text that may contain any client string |
| First `;` line in a section is the header | Column names travel with the data, so a reordered return is visible |
| One record per line, `;`-separated | Survives copy-paste out of an EditBox; commas appear inside client strings, semicolons do not |
| Absent values print as the literal `nil` | Distinguishes "the API returned nothing" from an empty string; the parser preserves it as an absent key |
| Booleans print `true` / `false` | `tostring` already does it; anything else needs a mapping nobody remembers |
| Colour codes stripped, `\|` replaced with `!` | Escape codes corrupt the display and make rows unparseable. **Lossy — never reversed** |
| `key=value` scalars, several per line if separated by 2+ spaces | Summary lines read better than a one-column table; the parser splits on the double space |
| Section names carry context inline (`CRITERIA PROGRESSBAR ach=62012 Journeyman Alchemist`) | The parser keeps the full label, so a sample's origin is never lost |

The emitter idiom worth copying rather than re-deriving:

```lua
local out = {};
local function w(s) out[#out+1] = s; end;
local function n(v) if v == nil then return "nil"; end return tostring(v); end;
```

`n()` on every field is what keeps `nil` in the row instead of shortening it and silently
shifting every column after it.

### What the parser does

- `== SECTION ==` → a key in `sections`, uppercased with non-word runs collapsed to `_`; the
  original stays in `label`.
- Header + rows → ordered `columns` and `rows` (array of maps).
- `nil` → key omitted from that row. `true`/`false` → booleans. Integers and decimals →
  numbers. Everything else → string.
- A row whose field count disagrees with the header is **not** guessed at: kept as
  `{ raw = "..." }` under a `WIDTH MISMATCH` comment. A shifted row is the failure most likely
  to poison a fixture quietly, so it is made loud.
- The whole paste → `raw`, in a long bracket that escalates if the text contains `]]`.

### The typing gap

Text cannot distinguish `0` from `"0"`, and the parser guesses number. For columns the API
documents as strings, pass `--string-col`:

```sh
--string-col quantityString --string-col charName --string-col name
```

`quantityString` is the one that bites: a localised, pre-formatted client string (`"0 / 150"`),
fine for display and never for arithmetic. A fixture typing it as a number teaches a spec the
wrong thing about the API.

Quoting strings in the emitter was considered and rejected — it makes the paste harder for a
human to scan mid-session, and the emitter cannot know which returns are strings any more
reliably than we can. **This whole gap is why shape 1 is preferred**: `Debug/` emits real Lua,
so the distinction is simply preserved.
