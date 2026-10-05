---
name: api-guard
description: Write or review a function in LegacyNext/Api/ — the only layer allowed to touch WoW globals. Use this whenever you are about to add, edit or review anything in Api/, wrap a WoW global or C_* call, read a Constants value, enumerate achievements or categories, read trait currency or the reward track, or write a stub in spec/stubs/ that has to match an Api/ signature. Also use it when a request is phrased as a feature ("show the points left", "list the closest challenges") but needs a new client read to land, and when reviewing a diff that touches Api/ or .luacheckrc read_globals. Every read gets feature-detected, pcall'd and issecretvalue-guarded, returns plain tables or nil plus a reason, and lands with a pin-stamped citation — because this client cannot be run interactively, so an unguarded read fails as a silent empty frame rather than a test.
---

# Writing Api/

`Api/` is the blast wall. Everything above it — `Model/`, `UI/` — is ordinary Lua that can be
tested, and stays that way only because every WoW global lives behind this one layer. That
makes `Api/` the place where a beta client's churn is absorbed, and the place where a mistake
is most expensive: Alex cannot run the game, so a bad read does not fail as a red test. It
fails as an empty frame, weeks later, with no error to paste.

`LegacyNext/Api/Api.lua` is written and green, so most of what follows is already embodied
there. Read the neighbouring function before adding one: matching the layer's existing shape
matters more than matching this document, and where the two disagree, **the code wins and this
skill is what needs fixing**.

Verify the symbol first. `forever-api-lookup` is the prerequisite, not a parallel option —
this skill assumes you already have a signature, a `file:line`, and an evidence tier for
everything you are about to call. If you do not, stop and go get them; the guard below
protects against the client changing, not against a signature you guessed.

## The guard, and why each part is there

```lua
--- Spendable Legacy points for this character.
-- C_Traits.GetMaxAvailableTraitCurrency(traitCurrencyID, excludeStagedChanges) -> number
-- doc:  <file>:<line>        <- fill both from forever-api-lookup output, never from memory
-- used: <file>:<line>
-- pin:  <sha> (<version.txt>)
function Api.GetSpendablePoints()
	local currencyId = Api.GetConstant("LEGACY_POINTS_TRAIT_CURRENCY_ID")
	if not currencyId then
		return nil, "no currency id"
	end

	local result = call("C_Traits.GetMaxAvailableTraitCurrency", currencyId, true)
	local cap = result and result[1]
	if type(cap) ~= "number" then
		return nil, "GetMaxAvailableTraitCurrency unavailable"
	end

	return cap
end
```

`call` is the shared guard in `Api.lua` and does four of the five gates below for you —
resolve, feature-detect, `pcall`, secret-check — then deep-copies any table before handing it
up. Read it at `LegacyNext/Api/Api.lua:210` (line at the time of writing; grep for
`local function call`) rather than writing a second one beside it. The
citation placeholders are placeholders on purpose: an example carrying real-looking line
numbers gets copied, and a copied citation that was never verified is exactly the failure the
pin stamp exists to catch.

Five gates, each earning its place:

**Feature-detect the function, never the client.** Many addons test `interface >= 100000` or
branch on `WOW_PROJECT_ID` to decide what exists, and they break here specifically: Forever
reports Mainline, ships interface 16001, and has a doc set that matches neither retail nor
Classic. CLAUDE.md forbids both tests outright. `type(fn) ~= "function"` is the only question
that stays true across a beta.

**`pcall` even a function that exists.** Presence is not readiness. A trait read before the
config exists, an achievement read with a stale index, a struct read during a loading screen —
these error rather than return nil, and an error thrown inside a `PLAYER_LOGIN` handler kills
the rest of that handler. Worse, the client stops surfacing Lua errors after 100, so the
second failure of a session may never be visible at all.

**Guard with `issecretvalue`, and feature-detect the guard too.** Midnight's addon
restrictions apply to this client. We believe none of our reads touch secret values, but
"believe" is doing real work in that sentence, and the cost of being wrong is a value that
poisons arithmetic downstream rather than erroring at the source. Where the generated doc says
`SecretArguments = "NotAllowed"`, note it in the citation — that function refuses tainted
input and is likelier to fail under the restrictions.

**Type-check what comes back.** The doc says what the function returns in this build. The
build changes weekly. A `type()` check turns "Blizzard changed a return" into a clean reason
string instead of a `nil` arithmetic error three layers up in `Model/`.

**Return plain data, or `nil` plus a reason.** Reasons are read by humans — `Debug/` prints
them and the UI's empty state shows them. Name the symbol that failed, because a screenshot
saying "C_Traits.GetTreeCurrencyInfo missing" ends an investigation that "could not load
points" would start.

The helpers already exist — `call`, `resolve`, `isSecret`, `Api.GetConstant`, plus the failure
tally that lets `/lgn probe` name which symbol broke. `references/patterns.md` covers what each
guarantees and which of the five shapes fits which read: scalar, struct with defensive fields,
list enumeration, multi-return bare global, constant with a labelled source. Read it before
writing the second function of a task.

## Nil is three different things, and the UI needs to tell them apart

`nil` from an `Api/` function can mean the API is gone, the API worked and there is genuinely
nothing, or a real error. Collapsing them produces a frame that says "no challenges" when the
truth is "this build renamed a function".

So: `nil, reason` means it failed. An empty table means it worked and found nothing. A
populated table means data. `Model/` and `UI/` can then be honest — "nothing left to earn"
versus "could not read your challenges" are different screens, and only one of them is a bug
report.

## What this layer may and may not call

**Never** `C_Traits.ResetTree`, any purchase API, any commit or staging API. Read-only, always
(CLAUDE.md, Hard constraints). A clean Tier A+B verification of a mutating function means it
is real and correctly documented; it does not license calling it. Blizzard's own UI calls
these; we do not.

**Never** `C_AddOns.LoadAddOn`. `Blizzard_LegacySystem` is load-on-demand and every C API we
need works without it — verified in game, with the constants present while
`IsAddOnLoaded("Blizzard_LegacySystem")` returned false. Only its Lua scaffolding is absent,
and we reimplement that.

**Never** `SetAchievementSearchString` or the filtered-achievement API as a source of truth.
It is global state shared with Blizzard's Achievement UI: 0 at login, 111 after any call,
changing under us whenever the player opens their own achievements. Enumerate directly:
`GetCategoryList()` → `GetCategoryNumAchievements(categoryID)` →
`GetAchievementInfo(categoryID, index)`. That decision is locked in `docs/status.md`; do not
relitigate it without new evidence.

**Never hardcode** an achievement, category or criteria ID. They churn through beta. The six
Legacy *constants* are different — read them from `Constants.LegacyConsts.<NAME>` at runtime,
with the CLAUDE.md literal as a labelled fallback only, never as the primary source.

## Cost is a design constraint, not an optimisation

A full sweep is 111 challenges × (one `GetAchievementInfo` + one `GetAchievementNumCriteria` +
n × `GetAchievementCriteriaInfo`) — and following `criteriaType` 8 meta chains multiplies that
again, since `Explorer` is hundreds of subzones deep. That is fine once per refresh and
catastrophic per frame.

So enumeration functions return the whole snapshot and the caller holds it; `UI/` never calls
`Api/` from a draw path. Cache in memory within a session where a refresh trigger exists, and
do **not** cache trait or currency data across an unknown event boundary: which of
`TRAIT_CONFIG_UPDATED`, `TRAIT_TREE_CHANGED` and `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`
actually fire is still outstanding (`docs/status.md`, C2). Until that comes back, re-read on
show — which is what Blizzard's own Legacy UI does, and the only precedent we have.

## Three shapes of criteria, not two

Any function returning criteria progress has to handle all three, because a third of the list
is the awkward one:

- **18 progress-bar** criteria (`criteriaFlags` bit 1) — a real `quantity`/`reqQuantity`
  fraction.
- **59 checklist** criteria — boolean per criterion; remaining is a count.
- **34 with no criteria at all** — binary, expose no progress through the API. Return them as
  a distinct case, not as `0/0` and not as 0%. Flattening them into "0% done" is how a third
  of the list ends up permanently pinned to the top of a closest-to-done sort.

`GetAchievementInfo`'s own `points` field reads **0** on Legacy challenges — the points come
from `C_Traits.GetTraitCurrencyForAchievement`. Every point-bearing challenge awards exactly
1 today, but do not hardcode 1; read it.

## What lands with the function

A new `Api/` read is not done when it returns the right value. Four things ship with it, and
each has a specific failure it prevents:

1. **The citation comment**, with the **pin stamp**. Line numbers are pin-relative; after a
   bump they point at plausible wrong lines, which is worse than no citation because it still
   reads as verified. The pin is what makes the staleness detectable.
2. **A `read_globals` entry in `.luacheckrc`.** Lint will not fail without it: `Api/` reaches
   every global through `rawget`/`resolve`, so luacheck never sees the symbol. The entry is a
   manifest of what we depend on, kept exhaustive by convention. It is a claim that the symbol
   exists, and the runtime feature-detect is the real gate.
3. **A watchlist line, if the symbol is a bare global or a constant name.** `beta-build-bump`
   auto-discovers `C_Namespace.Function` references under `LegacyNext/`, so namespaced calls
   need nothing. `GetAchievementInfo` and `ACHIEVEMENT_FLAGS_ACCOUNT` cannot be discovered and
   go in `.claude/forever-tools/watchlist.txt` by hand. Miss the line and
   the symbol still appears in `full.diff` — it just stops being surfaced, which is how a
   silent break gets through a bump.
4. **A fixture in `spec/fixtures/` with a `Model/` test, an inline stub in the `Api` spec, or an
   honest `pending` test naming the queue row.** `spec/stubs/` holds only a README; `Api` specs
   inject trivial stubs inline (see the header of `spec/api/api_spec.lua`), and those exercise
   the guard, not a response shape. Stubs are driven by captured fixtures, never invented data.
   Where the fixture only covers a prefix of the returns, the stub returns that prefix and the
   spec asserts nothing about the tail — this
   mirrors the "at least N returns" rule, since nothing stops the real function returning more
   than any vendored caller consumes. No fixture yet? The test is `pending` with the command
   that unblocks it, queued via `ingame-script`.

Then lint and test before committing:

```sh
./tools/lua51/bin/luacheck LegacyNext spec
./tools/lua51/bin/busted
```

`safe-commit` runs both plus the forbidden-pattern checks, and is the right way to land this.

## Reviewing an Api/ diff

Read for the failure modes in order of how badly they bite:

1. A call with no feature-detect, or a feature-detect that tests the client rather than the
   function.
2. A field read that no citation covers — invented field names are the single most common way
   wrong code looks right. `reward.name or reward.toastDescription` exists because `name` is
   missing on some entries; a documented field list is a floor, not a contract.
3. A write API, or a write-shaped name.
4. A hardcoded achievement, category or criteria ID; a constant read from a literal instead of
   `Constants.LegacyConsts`.
5. A citation with no pin stamp, or a pin stamp that disagrees with the pin `forever-env` reports.
6. `nil` used for both failure and emptiness.
7. WoW globals reached from `Model/` or `UI/` — that is the architecture violation that costs
   the test suite.
