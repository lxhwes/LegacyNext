# Distribution

Packaging is via [BigWigsMods/packager](https://github.com/BigWigsMods/packager), configured
in `.pkgmeta`. Nothing is wired into CI yet — CI only lints and tests.

## Known problems, not solved

Both of these are recorded because they will bite at release time, not because anyone has
worked them yet.

**The packager is reported to tag unknown interface numbers as retail.** Interface 16001 is
not a number the packager knows, and the reported behavior is that it falls back to the
retail flavor. Forever ships on the `wow_classic` product line, so a retail tag is the wrong
flavor for upload. Unverified by us — reported by other addon authors.

**wow-build-tools will not bump 16001.** Its interface-bumping step does not recognize the
number and leaves it alone, so any automated TOC bump has to be treated as a no-op rather
than trusted.

Neither is in scope for Phase 0. Before the first real release, run the packager in dry-run
against a tag and check what flavor it actually emits.

## Unverified in `.pkgmeta`

`move-folders` lifts `LegacyNext/LegacyNext` to the package root, which is the usual idiom
for a repo whose addon sits in a subdirectory. It has not been run. If the packager produces
a doubled `LegacyNext/LegacyNext` path in the zip, that line is why.
