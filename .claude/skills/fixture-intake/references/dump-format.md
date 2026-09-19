# The dump format

One contract with three consumers: the ad-hoc WoWLua scripts in `docs/ingame-commands.md` that
emit it today, `Debug/`'s `/legacynext dump` that will emit it tomorrow, and
`scripts/dump_to_fixture.py` that parses it. Drift between them does not error — it produces a
fixture that is subtly wrong, or a capture that has to be hand-transcribed. Both waste a round
trip through a human, which is the one cost this project cannot absorb.

## Shape

```
== SECTION NAME ==
col1;col2;col3
value;value;value
value;value;value

== ANOTHER SECTION ==
key=value
key=value  otherKey=value

== FREE SECTION ==
anything that is neither
```

Rules, and the reason for each:

| Rule | Why |
|---|---|
| Sections open with `== NAME ==` on its own line | The only unambiguous delimiter in text that may contain any client string |
| First `;` line in a section is the header | Column names travel with the data, so a fixture is self-describing and a reordered return is visible |
| One record per line, `;`-separated | Survives copy-paste out of an EditBox; commas appear inside client strings, semicolons do not |
| Absent values print as the literal `nil` | Distinguishes "the API returned nothing" from an empty string, which the parser then preserves as an absent key |
| Booleans print as `true` / `false` | `tostring` already does this; anything else needs a mapping nobody will remember |
| Colour codes stripped, `\|` replaced with `!` | Escape codes corrupt the display and make rows unparseable. Lossy on purpose — never reversed |
| `key=value` for scalars, several per line allowed if separated by 2+ spaces | Summary lines read better than a one-column table, and the parser splits on the double space |
| Section names carry context inline (`CRITERIA PROGRESSBAR ach=62012 Journeyman Alchemist`) | The parser keeps the full label, so which achievement a sample came from is never lost |

The canonical emitter, worth copying rather than re-deriving:

```lua
local out = {};
local function w(s) out[#out+1] = s; end;
local function n(v) if v == nil then return "nil"; end return tostring(v); end;
```

`n()` on every field is what makes `nil` survive as `nil` instead of shortening the row and
silently shifting every column after it.

## What the parser does with it

- `== SECTION ==` → a key in `sections`, uppercased with non-word runs collapsed to `_`. The
  original stays in `label`.
- Header + rows → `columns` (ordered) and `rows` (array of maps, header names as keys).
- `nil` → the key is omitted from that row.
- `true` / `false` → booleans. Integers and decimals → numbers. Everything else → string.
- A row whose field count disagrees with the header is **not** guessed at: it is kept as
  `{ raw = "..." }` with a `WIDTH MISMATCH` comment above it. A shifted row is the failure most
  likely to poison a fixture quietly, so it is made loud.
- `key=value` lines → `values`.
- Anything else → `lines`, verbatim.
- The whole paste → `raw`, in a long bracket whose level escalates if the text contains `]]`.

## The typing gap

Semicolon text cannot distinguish `0` from `"0"`, and the parser guesses number. For columns
the API documents as strings, pass `--string-col`:

```sh
--string-col quantityString --string-col charName --string-col name
```

`quantityString` is the one that bites: it is a localised, pre-formatted client string
(`"0 / 150"`), fine for display and never for arithmetic. A fixture that types it as a number
teaches a spec the wrong thing about the API.

The alternative — quoting strings in the emitter — was considered and rejected: it makes the
paste harder for a human to scan mid-session, and the emitter cannot know which returns are
strings any more reliably than we can.

## What Debug/ must keep

`Debug/`'s dump replaces the ad-hoc scripts, and inherits the format so that every capture from
here on parses with the same tool:

1. Emit the section/header/row shape above, unchanged.
2. Print `nil` for absent values, via a single helper — not `tostring(v)` at each site.
3. Strip colour codes and escape `|` before display.
4. Include a provenance section, so the fixture's required metadata comes out of the client
   instead of being remembered:

```
== META ==
addonVersion=0.0.1
build=1.60.1.69913
interface=16001
date=2026-09-18
character=Fresh (level 1 Paladin), points spent=0
```

That section is the one addition worth making to the format. Every required argument to
`dump_to_fixture.py` exists because a human had to supply it by hand; a client that prints its
own build and character state removes the step where that gets typed wrong.

5. Write into a copyable multiline EditBox. Chat truncates and wraps, and the fallback
`print` loop is for when a frame primitive turns out to be missing — see the fallback note in
`docs/ingame-commands.md`, since `UIPanelScrollFrameTemplate`, `ChatFontNormal` and
`SetColorTexture` are all unverified on Forever.
