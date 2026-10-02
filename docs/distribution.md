# Distribution

Packaging is [BigWigsMods/packager](https://github.com/BigWigsMods/packager) (`release.sh`),
configured in `.pkgmeta`. CI (`.github/workflows/ci.yml`) only lints and tests; ~~nothing
packages or uploads yet.~~ since 2026-09-30, `.github/workflows/release.yml` packages on a
pushed `v*` tag and creates a GitHub release. CurseForge upload stays off until the TOC has a
project ID and the `CF_API_KEY` secret exists (§4).

Everything below was checked on 2026-09-19 against `release.sh` from `master`
(`curl https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh`, 3374 lines,
head commit `e50a250f` 2026-09-18). Anything not run by us is marked unverified.

## 1. Packager and interface 16001: not reproduced

The report ("unknown interface numbers fall back to retail") was true until 2026-09-17.
PR #202 "Add WoW Forever support", merged `7391c8de` 2026-09-17, added a `forever` game type.
The floating `v2` tag the GitHub Action uses resolves to `e50a250f` (2026-09-18), so
`BigWigsMods/packager@v2` includes it.

Command: `gh api repos/BigWigsMods/packager/commits/v2 --jq '.sha'` → `e50a250f`.

What `release.sh` does with `## Interface: 16001`, by line:

- `toc_to_type()` line 198: `16???) game_type="forever"`. The `*) game_type="retail"`
  fallback no longer applies to us.
- Line 1355: interface → version string via `printf "%d.%d.%d"`, so `16001` → `1.60.1`.
- `-g` (line 294) accepts `forever` or `camelot`, and a `1.6x.y` version string maps to
  `forever` (line 309). `## Interface-Camelot:` lines and `LegacyNext_Camelot.toc` are also
  recognised (line 79). None of this is needed for a single-flavor addon, and no `.pkgmeta`
  key sets game type.

Upload mapping per site (all from the same file):

| Site | Code | Result for `forever` |
|---|---|---|
| CurseForge | line 2838, `forever) game_id=88568` | sends `gameVersions` IDs whose `gameVersionTypeID == 88568` and `name == "1.60.1"`; falls back to the newest 88568 version if `1.60.1` is missing |
| WoWInterface | line 2955 | `WARNING: ... "forever" is not supported, ignoring`, upload skipped |
| Wago | line 3070 | uses `supported_forever_patches` |

Interface bumping: `grep -n -i bump release.sh` returns nothing. The packager never edits the
TOC's interface number, so the "build tools bump" concern is not a packager concern.

## 2. Dry run: move-folders and ignore both work

Commands, in a throwaway clone so the real checkout was untouched:

```sh
git clone /Users/alex/code/legacynext $TMPDIR/lgn-pack
cd $TMPDIR/lgn-pack && git tag v0.0.1-drytest
/opt/homebrew/bin/bash $TMPDIR/release.sh -d -e -r $TMPDIR/lgn-release
unzip -l $TMPDIR/lgn-release/LegacyNext-v0.0.1-drytest-forever.zip
```

Exit 0. Header output, verbatim:

```
Packaging LegacyNext
Current version: v0.0.1-drytest
Build type: non-retail version-forever non-alpha non-debug
Game version: 1.60.1
```

Later output, verbatim: `Moving LegacyNext/LegacyNext to LegacyNext` and
`Creating archive: LegacyNext-v0.0.1-drytest-forever.zip (v0.0.1-drytest-forever)`.

Zip root is `LegacyNext/LegacyNext.toc`, not `LegacyNext/LegacyNext/LegacyNext.toc`.
Contents: `LegacyNext.toc`, `Core.lua`, `Api/Api.lua`, `Model/Model.lua`, `UI/UI.lua`,
`Store/Store.lua`, `Debug/Debug.lua`, `LICENSE`, `README.md`, generated `CHANGELOG.md`.
The TOC inside the zip is byte-identical to the source (`## Interface: 16001`, no rewrite).

`ignore` was honoured: the output logged `Ignoring:` for every file under `spec/`, `docs/`,
plus `CLAUDE.md` and `vendor/PINS.md`, and none of `.pkgmeta`, `.luacheckrc`, `.busted`,
`.gitignore`, `.github` appear in the zip. `tools/` is gitignored so was never a candidate.

The `-forever` zip suffix is the `{classic}` slot of `file_template` (line 152,
`classic="-$game_type"` for any non-retail type). Expect it on every release.

macOS-only wart: changelog generation printed `sed: 2: ... unused label` because
`/usr/bin/sed` is BSD sed. `CHANGELOG.md` was still written (40 KB, readable). Unverified on
GitHub's Ubuntu runners, which use GNU sed.

`.pkgmeta` line 7 was updated in the same commit; it now reads `Verified against BigWigsMods/packager on 2026-09-19`.

## 3. CurseForge Forever game version: ~~could not test, needs a token~~ answered 2026-09-30 by another addon's uploads

The packager reads `https://wow.curseforge.com/api/game/wow/versions` with an
`x-api-token` header (line 2823). Without a token:

```
curl -sS -o /dev/null -w '%{http_code}' https://wow.curseforge.com/api/game/wow/versions
401
```

No `CF_API_KEY` / `CF_API_TOKEN` is set in this environment (checked by name only), so
whether version type `88568` exists and carries a `1.60.1` entry is unverified. The public
site returned 403 to curl for `https://www.curseforge.com/wow/search?gameVersionTypeId=88568`.

The packager maintainers hardcoded `88568` two days ago, which they would only do against a
real CurseForge type ID. Circumstantial, not a test. Alex, in a browser, either of:

1. `https://legacy.curseforge.com/wow/addons` → any project you own → Upload File → the
   game-version picker. Look for a section named World of Warcraft Forever, Classic+, or a
   `1.60.1` entry. If present, publishing into it is possible.
2. With a CurseForge API token in hand, run (the token never lands on disk):
   `curl -s -H "x-api-token: $CF_API_KEY" https://wow.curseforge.com/api/game/wow/versions | jq '.[] | select(.gameVersionTypeID == 88568)'`
   Expect at least one entry with `"name": "1.60.1"`.

**Answered by another addon's uploads, 2026-09-30.** Legacy Forever (CurseForge project
1705879) releases through `BigWigsMods/packager@e50a250` (v2.6.1), with `CF_API_KEY` set, and
does nothing special for Forever. Its last five release runs passed (`api.github.com`, workflow
`release.yml`). Its v0.6.7 `release.json` reads `"flavor": "forever", "interface": 16001`.
CurseForge lists the resulting files under game version `1.60.1`:

```
curl -sS "https://api.cfwidget.com/1705879" | jq '[.files[:3][] | {name, versions}]'
# LegacyForever-v0.6.7-forever.zip, v0.6.6, v0.6.5 — each "versions": ["1.60.1"]
```

So CurseForge has a Forever `1.60.1` version and the packager uploads into it. The type ID
88568 itself is not shown by that endpoint. It is not our upload either, so our first release
is still the real test, but the browser and token checks above are no longer needed.

WoWInterface, verified: `curl https://api.wowinterface.com/addons/compatible.json` lists
games `Cata-Classic`, `Classic`, `Retail`, `TBC-Classic`, `WOTLK-Classic` and no `1.6x`
interface. Nothing to publish into; the packager already skips it with a warning.

Wago, verified: `curl https://addons.wago.io/api/data/game | jq '.patches.forever'` →
`["1.60.1"]`. Wago already has the category, and the packager's version string matches it.

## 4. Release workflow: wired 2026-09-30

`.github/workflows/release.yml` runs when a tag matching `v*` is pushed. Job `lint-and-test`
~~is a copy of `ci.yml`'s job~~ calls `ci.yml` itself through `workflow_call`, since
2026-10-01 (PR #4 review: two copies of the action pins would drift). `ci.yml`'s `push` trigger
is now branches-only, so a tag runs the gate once. Job `package` needs it, checks out with
`fetch-depth: 0` for the changelog, and runs `BigWigsMods/packager@v2` with no arguments, so
no `-g`. It has `permissions: contents: write` so the packager can create the GitHub release.

`gh api repos/BigWigsMods/packager/commits/v2 --jq '.sha'` →
`e50a250f8705041e40f2fa1ddcb280a686d65aa0`, the same commit as §1 and as `master`. Line
numbers below are from `release.sh` at that commit.

Secrets, by name: `CF_API_KEY: ${{ secrets.CF_API_KEY }}` (read at line 494) and
`GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}` (line 496), which Actions provides. `WAGO_API_TOKEN`
is left out: the packager README says only that Wago uploads require it.

CurseForge stays off until both `## X-Curse-Project-ID` in the TOC and the `CF_API_KEY` secret
exist. The TOC has had `## X-Curse-Project-ID: 1721646` since 2026-10-01, when Alex created
the project. Whether the secret is set is checked by `gh secret list`, by name only. Line 1329 reads the ID from the TOC, and line 1481 sets `project_site` only when it is
numeric. Then `upload_curseforge` returns before any request (line 2818):

```sh
if [[ -n "$skip_cf_upload" || -z "$slug" || -z "$cf_token" || -z "$project_site" ]]; then
```

Dry run on the branch, in a throwaway clone:

```sh
git clone --branch chore/release-packaging <worktree> $TMPDIR/lgn-pack-relwf
git -C $TMPDIR/lgn-pack-relwf tag v0.1.0-drytest
/opt/homebrew/bin/bash $TMPDIR/release.sh -d -e -t $TMPDIR/lgn-pack-relwf -r $TMPDIR/lgn-release-relwf
unzip -p $TMPDIR/lgn-release-relwf/LegacyNext-v0.1.0-drytest-forever.zip LegacyNext/LegacyNext.toc | grep '^## Version'
```

Header, verbatim, with no `CurseForge ID:` line after it (lines 1480-1482 print one only when
the TOC has an ID):

```
Packaging LegacyNext
Current version: v0.1.0-drytest
Build type: non-retail version-forever non-alpha non-debug
Game version: 1.60.1
```

Then `Creating archive: LegacyNext-v0.1.0-drytest-forever.zip (v0.1.0-drytest-forever)`. The
packaged TOC reads `## Version: v0.1.0-drytest`. That is its only content change; the packager
also writes CRLF line endings.

Also seen in that run:

- The token is replaced in every copied file, not just the TOC. A `Core.lua` comment naming it
  came out as `v0.1.0-drytest`. That is why `getVersion` tests for a leading `@` instead of
  comparing against the token, which would be rewritten too.
- The zip's `CHANGELOG.md` is generated from git history (the whole log, as no earlier tag
  exists). The hand-written file is copied, then overwritten. A manual changelog is used only
  when `.pkgmeta` sets `manual-changelog` (lines 1039, 2422). Not decided.
- `.claude/` is absent from the zip. Line 1829 prunes every dot-path before `ignore` is read.
- The BSD `sed` warning from §2 appeared again.

Unverified until the first real tag: the GitHub release. The clone's origin was a local path,
so the packager found no GitHub slug (line 829 wants an `https://github.com` URL), and `-d`
skips uploads anyway.

## Related: wow-build-tools

`McTalian-WoW-Addons/wow-build-tools` added Forever in `1188581a` "support the WoW Forever
(1.60.x) client line (#243)", 2026-09-17, release v1.7.0 (`gh api
repos/McTalian-WoW-Addons/wow-build-tools/commits`). The earlier note that it would not bump
16001 predates that commit. We do not use it; its bump behaviour is untested by us.

## Open

- ~~CurseForge type 88568 needs the browser or token check above before the first upload.~~
  Answered 2026-09-30 by Legacy Forever's uploads landing under `1.60.1` (§3). Our first
  upload is the remaining check.
- ~~`BigWigsMods/packager@v2` is not wired into CI. When it is, `-g` is unnecessary; the TOC
  alone yields `forever` / `1.60.1`.~~ Wired 2026-09-30 in `release.yml`, without `-g` (§4).
- ~~`.pkgmeta`'s ignore list did not include `.claude/` at dry-run time, and whether the packager
  skipped it was not recorded. `.claude` is being added to the ignore list on 2026-09-19; the
  next dry run should confirm it is absent from the zip.~~ Confirmed absent 2026-09-30 (§4).
  The packager prunes dot-paths before reading `ignore`.
- The zip ships a generated `CHANGELOG.md`, not the hand-written one, unless `.pkgmeta` sets
  `manual-changelog` (§4).
- The first real `v*` tag is the check for the GitHub release. The first upload with a project
  ID and `CF_API_KEY` is the check for CurseForge.
