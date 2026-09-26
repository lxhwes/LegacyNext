---
name: ingame-script
description: Author, verify and hand over a script or command for Alex to run in the live Forever client, and queue it in docs/ingame-commands.md. Use this whenever a question can only be answered by the running game — an API's real return values, whether an event fires, what a struct actually contains, a mid-progress criterion, whether a frame template exists — and whenever you are about to write, edit or review a WoWLua block, a /dump one-liner, an /etrace ask, or anything in docs/ingame-commands.md. Also use it the moment a lookup comes back unverifiable (forever-api-lookup Tier C), since the queued command is what unblocks the work. Round trips through a human are the scarcest resource on this project, so every script gets batched, parse-verified in both its multi-line and newline-stripped forms, and written into the queue rather than left in chat.
---

# In-game script handover

Alex cannot run the game while we work. Every question that needs the live client costs a
context switch for him and a wait for us, and he answers by pasting text back. That makes
round trips the scarcest resource on the project — scarcer than tokens, scarcer than your
time. One script that answers six questions is worth six times one that answers one, and a
script that fails to parse on arrival costs a whole round trip to learn nothing.

So this skill is mostly about spending the round trip well, and about the two mechanical
failures that waste one entirely.

## Before you write anything: is the round trip needed?

Three checks, cheapest first. Skipping them is how a question that was answered in September
gets asked again.

```sh
grep -n 'verified in game' docs/legacy-internals.md   # what the client has already told us
awk '/^---/{exit} {print}' docs/ingame-commands.md    # queue and Closed tables, up to the first rule
sed -n '/Outstanding — needs the game/,/^## /p' docs/status.md
```

A lot of what feels unverifiable has in fact been settled: 111 challenges, one shared
`configID` across all three trees, reward thresholds at 15/25/40/55, the six constant values
on a fresh login. Sections A and B are **done** (2026-09-18). Section C is what is open, and
it needs a *played* character — which is a different and scarcer ask than "run this on any
character", so put a question in the right section or it waits on the wrong precondition.

## Then: is a script the right vehicle?

The client ships tools that beat a script, and reaching for Lua when one of them fits spends
Alex's attention on nothing. Pick by what you actually need:

**Before anything below: the addon may already do it.** `/lgn dump [section]` and `/lgn probe`
are written and are the preferred capture path (CLAUDE.md, In-game workflow) — they emit a Lua
literal that needs no parsing, into a copyable window, with client metadata attached. Hand over
raw Lua only for something the addon does not read yet. A new ad-hoc script that duplicates a
`Debug/` section spends a round trip to get worse data.

| Need | Use | Not |
|---|---|---|
| Anything `Api/` already reads | `/lgn dump <section>` | A fresh sweep script |
| Which of our API calls work on this client | `/lgn probe` | A `pcall` harness |
| Which events fire, and their payloads | `/etrace`, filtered to the event names | An event-probe script. One was written here and then retired — `/etrace` does it better. |
| One ID off something on screen | idTip — hover it, read the tooltip | A sweep |
| Whether a symbol exists at runtime | `/api` browser | A `pcall` harness |
| One nested table's shape | `/tinspect Foo` | `/dump`, which flattens badly |
| One scalar, short enough to read in chat | `/dump <expr>` | A WoWLua block |
| A sweep, several questions, or anything over a few lines of output | WoWLua block with an EditBox | Chat spam |

Two length rules that look contradictory in the docs, and are not:

- A **WoWLua block has no length limit** — it is a multi-line editor, so the 255-character
  chat limit does not shape it at all.
- A **`/dump` or `/run` one-liner pasted into chat or a macro does**: 255 characters, one
  line, self-contained. Longer than that and it silently truncates.

So the limit follows the vehicle, not the question. If a one-liner will not fit, that is the
signal to make it a WoWLua block, not to golf it.

## The two mechanical failures

Paste paths strip newlines. Alex's script may arrive at the client as one long line, and both
of these turn that into a wasted round trip:

**A missing semicolon.** `local FACTION = 2802` followed by `local out = {}` flattens to
`2802local out` and the client says `malformed number near '2802local'`. So terminate every
statement with `;` — including the last one, including single-statement lines, including
inside `for` bodies.

**A `--` comment.** Flattened, it swallows the entire rest of the script. No error, no output,
or a partial run that looks like a real result. This is worse than the semicolon failure
because it can come back as data rather than as an error. So no `--` comments at all, and no
`--[[ ]]` blocks either. If a line needs explaining, explain it in the prose around the block
where Alex can read it, which is where it is useful anyway.

Both properties have to survive edits. If you touch one line of an existing script in
`docs/ingame-commands.md`, re-run the gate below over the whole block.

## The gate: verify it parses, both ways

```sh
.claude/skills/ingame-script/scripts/check_script.sh docs/ingame-commands.md
.claude/skills/ingame-script/scripts/check_script.sh /tmp/draft.lua
```

Given a markdown file it extracts every ```lua block and checks each; given a `.lua` file it
checks the file. For each block it parses the multi-line form, then parses a copy with the
newlines *deleted* (not replaced with spaces — deletion is the worst case and the one that
produced `2802local`), and greps for `--` comments and for write APIs. It needs `luac` from
the project toolchain and **fails loudly rather than passing when it cannot find one**, since
a gate that silently skips is worse than no gate.

Never hand over a block that has not been through it. A parse failure discovered by the gate
costs seconds; the same failure discovered by Alex costs a round trip and some goodwill.

## Writing the script

**Batch ruthlessly.** Every open question that can share a character state goes in one block.
The U2 block in `docs/ingame-commands.md` answers truncation, `IsTruncated`, frame protection
and three template checks in one paste. That is the target shape, not an exception. If two questions need different character states, that is
two sections, not two round trips against the same state.

**Enumerate rather than hardcode.** IDs churn through beta and CLAUDE.md forbids hardcoding
achievement, category and criteria IDs in the addon; a script that discovers its own IDs also
keeps working after a build bump, and tells you the ID as part of its output. `GetCategoryList()`
returns only Legacy categories here, so enumeration is cheap.

**Read-only, in scripts too.** No purchase, commit, or `C_Traits.ResetTree`; nothing that
spends a point or stages a change. Alex's character is not a test fixture, and a script that
mutates his state cannot be re-run to check a result. Also do not call
`SetAchievementSearchString` — it is global state shared with Blizzard's Achievement UI, so a
probe that calls it changes what his UI shows afterwards.

**Print in a parseable shape.** Semicolon-separated rows under a header line, grouped by
`== SECTION ==`, with `nil` printed as the literal `nil`. This is not decoration: the paste
that comes back is fed to `fixture-intake`, whose parser expects exactly that shape, and a
bespoke output format means transcribing by hand.

Strip WoW colour codes and escape the pipe before display, or the output arrives with
markup in it:

```lua
text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "!");
```

Then say in the prose that `|` came back as `!`, so nobody later mistakes a real bar for an
escape. (This is lossy on purpose — do not try to reverse it when the paste comes back.)

**Output into a copyable EditBox past a few lines**, using the `LNDump` block in the
"Copyable output" section of `docs/ingame-commands.md` rather than a new one. Chat truncates, wraps, and cannot be selected cleanly.

**Give it a fallback.** `UIPanelScrollFrameTemplate`, `ChatFontNormal` and `SetColorTexture`
are verified in game 2026-09-19 via the `/lgn dump` window, which is built on exactly those
and produced every committed fixture (queue row D3; `docs/ui-templates.md`). The fallback
stays because a build bump can remove any of them. So every EditBox script carries the
replacement in its prose:

> If it errors, replace everything from `if not LNDump then` to the end with
> `for _, line in ipairs(out) do print(line); end;` and tell me what errored.

A failure there is itself a finding — those are the primitives `Debug/` will be built on, and
learning one is missing costs nothing when the fallback is already in his hands.

## The handover

Write it into `docs/ingame-commands.md`, in the section matching the character state it needs,
and follow the structure the file already uses — it is the queue Alex works from in a beta
session, and a command that exists only in chat scrollback is a command that gets lost.

```markdown
## Script N — <what it answers, in one line>

<Preconditions: any character, or what progress it needs. Which questions it closes.>

```lua
<the block>
```

**What I need back:** <all of it, or which sections matter most if it is long>

**What I'm reading it for:**

- <the specific claim each part settles, and what a surprising value would mean>

<The fallback, if it builds a frame.>
```

"What I'm reading it for" is the part that earns its keep. It lets Alex notice that
`totalPoints` came back 63 instead of 65 and tell you so, instead of pasting 200 lines and
waiting for you to spot it. Write the expected value where you have one.

Then **stop**. Do not write code against the shape you expect the answer to have, do not mark
anything `[verified]`, and do not leave a test asserting an invented result. Mark the claim
`[unverified]`, leave the affected test `pending` naming the command that unblocks it, and say
plainly that you are blocked on the paste. Guessing past this point is the one failure mode
that produces confident wrong code in a client nobody can run.

## When the paste comes back

That is `fixture-intake`'s job: provenance, typed fixture files, stubs, un-pending tests, and
writing the finding into `docs/legacy-internals.md`, `CLAUDE.md` and `docs/status.md`. Hand
off rather than half-doing it here. The one thing that belongs to this skill is marking the
queue entry done with the date, the way Section B is marked, so the next session does not
re-ask.
