---
name: forever-api-lookup
description: Verify any WoW API symbol against the vendored Forever branch source before writing code that calls it, and cite file:line for the signature. Use this whenever you are about to write, review, edit, or stub a call to a WoW global or C_* namespace function, an event name, an Enum, or a Constants value in LegacyNext — including C_Traits, C_AchievementInfo, C_MajorFactions, GetAchievementInfo, GetAchievementCriteriaInfo, and anything in Api/ or spec/stubs/. Also use when asked "does this API exist", "what does this return", "is this the right signature", "what fields are on this table", when a test fixture needs a response shape, or when reviewing a diff that touches Api/. Forever is not retail — never answer from memory of retail WoW, wowpedia, or the MCP API server, because they describe a different client.
---

# Forever API lookup

LegacyNext targets WoW: Forever (interface 16001, build 1.60.1). Forever runs the retail
API but is *not* retail — its documentation diverges by roughly 6k lines and 26 extra doc
files. Answering from retail memory produces code that looks right and fails in a client
neither of us can run interactively. The vendored source is the only authority available
offline, so every API claim gets traced to a line in it.

This matters more than usual here: Alex cannot run the game, so a wrong signature does not
surface as a quick test failure. It surfaces as a debugging session with a `/dump` round
trip through a human.

## Check the cache before you search

`docs/legacy-internals.md` is standing research against a pinned checkout, and a lot of the
Legacy API surface is already traced there with `path:line` citations. Grep it first — if it
answers the question, you have saved a search.

It is a cache, not an authority, and caches go stale in one specific way here:

```sh
grep -m1 -A3 'Read-only research against' docs/legacy-internals.md   # the pin it was written against
git -C vendor/wow-ui-source rev-parse --short HEAD                   # the pin on disk now
```

If those disagree, the doc describes a build we are no longer pinned to. Treat its
source-derived claims as `[unverified]` until re-derived, say so out loud, and check
`docs/beta-builds.md` for what the intervening bump changed.

Which of the two wins depends on how the claim was established, and the doc marks this:

- **Source-derived claims** are someone's earlier reading of the same files you are about
  to read. They inherit any mistake that reader made, so **the vendored source wins**.
- **Claims marked `[verified in game <date>]`** came from a live client. That is evidence
  neither you nor the vendored tree can produce offline, so **the in-game result wins** —
  including where it contradicts the generated docs, which it demonstrably does.

Never "correct" an in-game observation with an inference from source. If they genuinely
conflict, that is a finding worth raising, not a discrepancy to resolve by picking the
tidier answer.

Even at a matching pin, you can check the citations mechanically rather than trusting them:

```sh
.claude/skills/forever-api-lookup/scripts/verify_citations.py docs/legacy-internals.md
```

It re-resolves every `path:line` against the checkout and exits non-zero if any broke. Worth
running after a bump, because drift here is silent: an insertion upstream shifts every
citation below it, and a shifted citation still *looks* verified.

## The one command

```sh
.claude/skills/forever-api-lookup/scripts/api_lookup.sh <Symbol>
```

Accepts a namespaced function (`C_Traits.GetTreeCurrencyInfo`), a bare global
(`GetAchievementCriteriaInfo`), an event literal (`ACHIEVEMENT_EARNED`), a constant
(`LEGACY_POINTS_TRAIT_CURRENCY_ID`), or a structure name (`TreeCurrencyInfo`).

It prints the pinned commit, the generated doc entry with every referenced structure
resolved inline, Blizzard's own call sites ranked by relevance, a read-only guard warning
where relevant, and a verdict naming the evidence tier. Run it once per symbol before the
symbol appears in code. Batch the lookups for a task in one turn — they are independent.

Two things about the call-site list are deliberate. It is bucketed (Legacy addons first,
then the achievement UI, then anything else) with the long tail truncated, because hits in
our own addons are worth more than the rest. And when you pass a namespace, hits under a
*different* namespace are quarantined in their own section: the bare global
`GetCategoryInfo` has twenty call sites here and tells you nothing about whether
`C_AchievementInfo.GetCategoryInfo` exists. Counting those as evidence is how a function
that does not exist gets waved through — which is a mistake this script made before the
quarantine was added.

Read the whole output before writing. The struct resolution in particular exists because
field names are where invention creeps in: `GetTreeCurrencyInfo` returns a
`TreeCurrencyInfo`, and guessing that it has `.spent` rather than reading the field list
is the failure mode this skill is for.

## Evidence tiers, and what each licenses

The script labels the result. What you do next depends on which:

**Tier A+B — documented and called by Blizzard.** Strongest. Trust the doc for the
signature and the call site for realistic arguments. Write the code.

**Tier A — documented, but nothing in the vendored UI calls it.** The signature is
reliable. What real arguments look like is not, and neither is whether the function is
wired up in this build. Write the code, note the absence of a call site in the citation.

**Tier B — undocumented, but Blizzard calls it.** Normal, not a red flag: the FrameXML
globals (`GetAchievementInfo`, `GetAchievementCriteriaInfo`, `GetNumFilteredAchievements`)
are all like this. Derive the return order from the call sites — Blizzard's local variable
names are the de facto parameter names.

Always prefer the call site that destructures the *most* returns, and read past the first
bucket before settling. A short destructure only tells you a prefix:
`GetAchievementCriteriaInfo` is taken to 7 values in `Blizzard_LegacySystem`, to 3 in
places, and to 9 in `Blizzard_AchievementUI`. The longest one you can see bounds what you
know — and it is a *lower* bound, not the true arity, since nothing stops the function
returning more than any vendored caller consumes. Say "at least N returns" and mark the
tail `[unverified]` rather than asserting the list is complete.

**Tier C — absent entirely.** How much this proves depends on what kind of symbol it is,
and the two halves of the search are not equally complete:

- *The generated docs are complete for namespaces and functions.* 639 files covering 284
  namespaces, dumped by Blizzard's own generator. So for a `C_Something.Foo` symbol,
  absence from the docs is **strong**. `C_LegacySystem` returns nothing anywhere in those
  639 files, which is good evidence that namespace does not exist, not an artifact of a
  narrow checkout. This does **not** extend to struct fields — see below.
- *The call sites are not complete.* Only the directories `vendor/PINS.md` lists are vendored.
  FrameXML-level symbols are now checkable, since `Blizzard_FrameXML`, `Blizzard_FrameXMLBase`
  and `Blizzard_SharedXML` are in the checkout, but a global called only from a directory
  PINS.md lists as outside the checkout looks identical to one that does not exist. Absence
  there is **weak**.

So: a missing `C_*` namespace or function you can call fake with confidence. A missing
bare global you cannot. Either way Tier C licenses refusing to invent a shape — and when
the docs are the strong half, it also licenses looking for the API under its real name
before going back to Alex. A user guessing `C_LegacySystem.GetTrackedChallenges` usually
wants the capability, not that exact spelling; finding `C_ContentTracking.GetTrackedIDs`
serves them better than a correct refusal. Follow the Tier C protocol below for whatever
remains genuinely unverifiable.

## A documented field list is a floor, not a contract

This one is settled by live-client evidence, so it outranks anything you can infer from the
vendored tree. The reward struct returned at runtime carries `description`, `isCollected`,
`toastDescription`, `rewardType` and `name` — five fields that appear nowhere in
`MajorFactionsDocumentation.lua:323-337`, the structure that documents it
[verified in game 2026-09-18, `docs/legacy-internals.md`].

So split what the docs guarantee:

- **Function signatures — reliable.** Argument order, types and nilability are what the
  generator emitted for this build. Trust them.
- **Struct field lists — a minimum.** A field in the docs exists. A field absent from the
  docs may still be there. Never conclude "the API can't give me X" from a doc field list
  alone, and never write code that assumes the documented list is the whole table.

In practice: read fields defensively in `Api/` (`reward.name or reward.toastDescription`
is the real pattern that came out of this), and when a feature seems to need a field the
docs don't mention, the answer is a `/dump` against the live client, not a redesign.

The same caution applies in reverse to the script's struct resolution — it expands the
documented fields, which is the floor, not an inventory of what comes back.

## The flavour trap

`Blizzard_AchievementUI` ships two copies of the same file:

```
Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua   <- cite this
Blizzard_AchievementUI/Cata/Blizzard_AchievementUI.lua       <- do not cite this
```

They are different eras of the API with different return counts. `GetAchievementCriteriaInfo`
returns 9 values in Mainline and is destructured to 3 in some Cata call sites. Grepping
without noticing which directory you landed in is a real way to ship a wrong signature; the
script flags every hit's flavour for exactly this reason.

Forever is the Mainline flavour. The evidence:
`Blizzard_LegacySystem/Blizzard_LegacySystemUtil.lua:5` calls
`GetNumFilteredAchievements()`, which exists only in the Mainline copy. Note also that
`Blizzard_LegacySystem.toc` declares `## AllowLoadGameType: camelot` while
`Blizzard_AchievementUI.toc` lists `mainline, tbc, wrath, cata, mists` and not `camelot` —
the toc gating does not cleanly explain how Forever loads it. Do not build a claim on that
gating; rely on the call-site evidence instead.

## Read-only is a hard constraint, and call sites do not override it

Blizzard's UI calls `C_Traits.ResetTree`, purchase, and commit APIs. LegacyNext never does
(CLAUDE.md, Hard constraints). A clean Tier A+B result for a mutating function means the
function is real and correctly documented — it does not mean we may call it. The script
warns on known write APIs and on write-shaped names; treat that warning as a stop, and ask
Alex rather than working around it.

## Feed the result into the code

`api-guard` covers writing the wrapper itself — the guard, the return contract, the stub. This
section is about what the *lookup* leaves behind. Three things come out of it and all of them
belong in the change:

**A citation comment** above the `Api/` function, so the next reader can re-verify without
repeating the search. Keep it to the facts:

```lua
-- C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges) -> TreeCurrencyInfo[]
-- doc:  SharedTraitsDocumentation.lua:537   fields: SharedTraitsDocumentation.lua:1188
-- used: Blizzard_LegacySystem/Blizzard_LegacySystemUtil.lua:35
-- pin:  70ef1b2 (1.60.1.69913)
```

The pin line is not decoration, and it is the reason the line numbers are safe to write
down. **Line numbers are pin-relative.** An insertion anywhere above shifts everything
below it, so after a bump these numbers point at plausible-looking wrong lines — which is
worse than no citation, because it still reads as verified. The pin stamp is what makes
that detectable: it says which build the numbers were true for.

So when you arrive at one of these comments at a different pin, do not nudge the number to
make it fit. Re-run `api_lookup.sh` on the symbol — it finds by name, so it always returns
the current line — and update the pin stamp with it. `verify_citations.py` will tell you in
bulk which comments went stale.

**The Api/ guard**, unchanged by what you found. Every call still feature-detects, `pcall`s,
and runs the `issecretvalue` guard when that global exists. A doc entry proves the function
is meant to exist in this build; it does not prove it is present at runtime, and beta churn
is the whole reason the guard is there. Where the doc says
`SecretArguments = "NotAllowed"`, say so in the citation — that function refuses tainted
input and is more likely to fail under the Midnight restrictions.

**A watchlist line, but only for symbols that cannot be auto-discovered.** The
`beta-build-bump` skill greps each new build's diff against
`.claude/skills/beta-build-bump/references/watchlist.txt`, and that is what turns a
3,000-line build diff into the few lines that can break us. It auto-discovers every
`C_Namespace.Function` under `LegacyNext/`, so namespaced calls need nothing from you. It
cannot discover bare FrameXML globals or constant names.

So: if this lookup is what puts a *bare global* (`GetAchievementInfo`) or a *constant*
(`LEGACY_TREE_ADVENTURE_ID`) into `Api/` for the first time, add it to that file in the
same change. This skill is the moment such a symbol enters the codebase, which makes it
the only reliable place to catch it. Miss the line and the symbol does not vanish from
`full.diff` — it just stops being surfaced, which is exactly how a silent break gets
through a bump.

## Tier C protocol

When a symbol cannot be verified, do not quietly proceed and do not silently drop the
feature. Do all three:

1. Mark the claim `[unverified]` wherever it is written down, matching the convention
   CLAUDE.md already uses.
2. Write the affected test as `pending` with the reason, rather than asserting an invented
   shape. CLAUDE.md: never invent API response shapes.
3. Queue the command via `ingame-script`, which owns authoring and verifying anything Alex
   pastes into the client, and stop rather than guessing past it. For a one-liner the shape is:

```
/dump C_Traits.GetTreeCurrencyInfo(C_Traits.GetConfigIDByTreeID(1187), 1187, true)
```

`docs/ingame-commands.md` is the queue Alex actually works from in a beta session, so a
command left only in chat gets lost. The 255-character, one-line limit applies to anything
pasted into **chat or a macro**, which is what a bare `/dump` is; a WoWLua block has no such
limit, so when a question will not fit on one line that is the signal to make it a block
rather than to golf it. Either way it has to be self-contained — pasteable by someone
mid-session who is not holding this context.

Check the file before writing a new command. Section A is already answered, and a lot of
what looks unverifiable has in fact been settled in game — 111 challenges, one shared
configID across all three trees, reward thresholds at 15/25/40/55. Once Alex pastes output
back, it becomes a fixture in `spec/fixtures/` and the test stops being pending.

## What is actually checked out — check, do not assume

The directories `vendor/PINS.md` lists: the original four Legacy and API-doc addons plus the
2026-09-19 widening (FrameXML, SharedXML, fonts, UI panel templates and more). Run
`ls vendor/wow-ui-source/Interface/AddOns` and compare against that file.

Verify it at the start of any lookup session rather than trusting this paragraph:

```sh
cat vendor/wow-ui-source/.git/info/sparse-checkout
ls vendor/wow-ui-source/Interface/AddOns
```

This is not pedantry. The checkout scope has been re-pinned mid-session before — the cone
was briefly widened to the full `Interface/` tree and then narrowed back, which silently
changed what "no call sites found" meant while work was in flight. The scope decides how
much a Tier C verdict is worth, so read it rather than remembering it. If the sparse set
or the pin has moved, say so plainly instead of re-deriving citations silently; a moved
pin during beta is itself the news.

Check `vendor/PINS.md` for the current set. FrameXML-level symbols are now checkable; only
symbols that live in directories PINS.md lists as outside the checkout (`Blizzard_MicroMenu`,
`Blizzard_SharedTalentUI`, `Blizzard_MajorFactions`, `Blizzard_Professions` at the time of
writing) stay `[unverified]`. Mark those rather than reasoning about them from retail.

**Do not widen the sparse checkout to get at them.** It is tempting and it works, but the
cone is shared state: widening it changes what every concurrent session sees, and a
lookup that runs during the widened window will record citations to files that vanish
when it narrows back. That has already happened here. Widening is a `PINS.md` change and
`beta-build-bump`'s call, so propose it rather than doing it.

The script exits with a pointer to `vendor/PINS.md` if the checkout is absent; the
sparse-checkout recipe there recreates it.

Do not reach for wowpedia, Wowhead, the Warcraft API MCP server, or retail memory to fill a
gap. They describe a different client, and a confident wrong answer costs more here than
"I could not verify this."
