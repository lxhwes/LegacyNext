#!/usr/bin/env bash
# Compare the vendored Blizzard reference checkout against the newest forever build,
# and (on --apply) move the pin forward.
#
# Two phases on purpose. `check` never touches the working tree, so the diff can be read
# and the bump abandoned with nothing to undo. `--apply` is the only thing that moves the
# checkout, and it refuses to run unless a check already produced artifacts for that SHA.
#
# Usage:
#   scripts/bump.sh                 # check: fetch, diff against the pin, write artifacts
#   scripts/bump.sh --apply <sha>   # move the vendored checkout to <sha>
#
# Exit codes:
#   0  check completed (read summary.txt for the verdict) / apply succeeded
#   3  already current, no new build
#  64  bad usage
#  69  vendored checkout missing
#  70  fetch or git operation failed

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VENDOR="$ROOT/vendor/wow-ui-source"
PINS="$ROOT/vendor/PINS.md"
SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCHLIST="$SKILL/references/watchlist.txt"

# The sparse-checkout set from PINS.md. Kept as an array: these must stay separate argv
# entries, and an unquoted string variable does not word-split under zsh.
PATHS=(
	Interface/AddOns/Blizzard_LegacySystem
	Interface/AddOns/Blizzard_LegacyChallengeTracker
	Interface/AddOns/Blizzard_APIDocumentationGenerated
	Interface/AddOns/Blizzard_AchievementUI
)

# Keyed by checkout path as well as target SHA, so two clones of this repo on one machine
# (a worktree, an eval sandbox) cannot read each other's artifacts and apply the wrong diff.
OUTROOT="${TMPDIR:-/tmp}/beta-build-bump/$(printf '%s' "$ROOT" | shasum | cut -c1-8)"

die() { echo "FATAL: $*" >&2; exit "${2:-70}"; }

[[ -d "$VENDOR/.git" ]] || die "no vendored checkout at $VENDOR
Recreate it with the sparse-checkout recipe in vendor/PINS.md, then retry." 69

# git noise that is not ours to fix: the macOS keychain credential helper fails to store
# anonymous credentials for a public repo, printing a fatal line on an otherwise fine fetch.
quiet_git() { git -C "$VENDOR" "$@" 2>&1 | grep -v 'failed to store:'; }

# Build number to .toc Interface number: 1.60.1 -> 1*10000 + 60*100 + 1 = 16001.
interface_for() {
	local v="$1" maj min pat
	IFS=. read -r maj min pat _ <<< "$v"
	[[ "$maj" =~ ^[0-9]+$ && "$min" =~ ^[0-9]+$ && "$pat" =~ ^[0-9]+$ ]] || { echo ""; return; }
	echo $(( maj * 10000 + min * 100 + pat ))
}

# ---------------------------------------------------------------- apply -----
if [[ "${1:-}" == "--apply" ]]; then
	NEW="${2:-}"
	[[ -n "$NEW" ]] || die "--apply needs the SHA that check reported" 64
	[[ -d "$OUTROOT/$NEW" ]] || die "no check artifacts for $NEW. Run scripts/bump.sh first,
read the diff, then apply. Applying blind defeats the point of the two phases." 64

	git -C "$VENDOR" reset --hard "$NEW" >/dev/null 2>&1 || die "reset to $NEW failed"
	echo "vendored checkout now at $NEW"
	git -C "$VENDOR" log -1 --format='  %h  %ci  %s' 2>/dev/null
	echo "  version.txt: $(cat "$VENDOR/version.txt" 2>/dev/null || echo unknown)"
	echo
	echo "vendor/PINS.md still records the OLD pin. Update it now, in the same commit."
	exit 0
fi

[[ $# -eq 0 ]] || die "unexpected argument '$1' (usage: bump.sh | bump.sh --apply <sha>)" 64

# ---------------------------------------------------------------- check -----
OLD="$(git -C "$VENDOR" rev-parse HEAD 2>/dev/null)" || die "cannot read vendored HEAD"
OLD_VERSION="$(cat "$VENDOR/version.txt" 2>/dev/null || echo unknown)"

# PINS.md is the record; the checkout is the reality. They drift when a previous bump was
# abandoned halfway, and every claim downstream is wrong if we do not notice.
PINNED_SHA="$(grep -oE '\b[0-9a-f]{40}\b' "$PINS" 2>/dev/null | head -1 || true)"

echo "fetching origin/forever ..." >&2
quiet_git fetch --depth 1 origin forever >/dev/null
NEW="$(git -C "$VENDOR" rev-parse FETCH_HEAD 2>/dev/null)" || die "fetch produced no FETCH_HEAD"

OUT="$OUTROOT/$NEW"
mkdir -p "$OUT"
SUMMARY="$OUT/summary.txt"
: > "$SUMMARY"

say() { echo "$@" | tee -a "$SUMMARY"; }

NEW_VERSION="$(git -C "$VENDOR" show "$NEW:version.txt" 2>/dev/null | tr -d '\r\n' || echo unknown)"
NEW_SUBJECT="$(git -C "$VENDOR" log -1 --format=%s "$NEW" 2>/dev/null)"
NEW_DATE="$(git -C "$VENDOR" log -1 --format=%ci "$NEW" 2>/dev/null)"

say "artifacts:   $OUT"
say "pinned:      $OLD  (version.txt $OLD_VERSION)"
say "newest:      $NEW  (version.txt $NEW_VERSION)"
say "             $NEW_DATE  $NEW_SUBJECT"
say ""

if [[ -n "$PINNED_SHA" && "$PINNED_SHA" != "$OLD" ]]; then
	say "PINS_DRIFT: vendor/PINS.md records $PINNED_SHA but the checkout is at $OLD."
	say "  A previous bump was left half-applied. Reconcile before trusting this diff."
	say ""
fi

if [[ "$OLD" == "$NEW" ]]; then
	say "NO_NEW_BUILD: already at the newest forever commit. Nothing to do."
	exit 3
fi

# Gethe's mirror re-pushes builds out of order: version.txt has gone 69893 -> 69876 -> 69913
# on consecutive commits. Newest commit does not mean highest build.
OLD_BUILD="${OLD_VERSION##*.}"
NEW_BUILD="${NEW_VERSION##*.}"
if [[ "$OLD_BUILD" =~ ^[0-9]+$ && "$NEW_BUILD" =~ ^[0-9]+$ && "$NEW_BUILD" -lt "$OLD_BUILD" ]]; then
	say "BUILD_WENT_BACKWARDS: $OLD_BUILD -> $NEW_BUILD. The mirror re-pushes out of order."
	say "  Do not apply without deciding this is really the build you want."
	say ""
fi

# --- .toc interface number --------------------------------------------------
EXPECTED_IF="$(interface_for "$NEW_VERSION")"
ACTUAL_IF="$(grep -oE '^## Interface: *[0-9]+' "$ROOT/LegacyNext/LegacyNext.toc" 2>/dev/null | grep -oE '[0-9]+$' || true)"
if [[ -n "$EXPECTED_IF" && -n "$ACTUAL_IF" && "$EXPECTED_IF" != "$ACTUAL_IF" ]]; then
	say "TOC_INTERFACE_STALE: build $NEW_VERSION implies Interface $EXPECTED_IF, .toc says $ACTUAL_IF."
	say ""
elif [[ -n "$EXPECTED_IF" ]]; then
	say "toc interface: $ACTUAL_IF, consistent with $NEW_VERSION."
	say ""
fi

# --- file-level change set --------------------------------------------------
git -C "$VENDOR" diff --name-status "$OLD" "$NEW" -- "${PATHS[@]}" 2>/dev/null > "$OUT/namestatus.txt"
git -C "$VENDOR" diff "$OLD" "$NEW" -- "${PATHS[@]}" 2>/dev/null > "$OUT/full.diff"

if [[ ! -s "$OUT/namestatus.txt" ]]; then
	say "VENDORED_DIRS_UNCHANGED: the build moved but none of the four vendored directories did."
	say "  This is the common case. The pin and version.txt still need updating; nothing else does."
	say ""
	say "next: scripts/bump.sh --apply $NEW"
	exit 0
fi

say "changed files, by directory:"
for p in "${PATHS[@]}"; do
	n=$(grep -c "	$p/" "$OUT/namestatus.txt" 2>/dev/null || true)
	[[ "${n:-0}" -gt 0 ]] && say "  ${n}	${p##*/}"
done
say ""
say "added / removed files (a vanished doc file means an API namespace went away):"
grep -E '^[AD]' "$OUT/namestatus.txt" | tee -a "$SUMMARY" || say "  (none — all modifications)"
say ""

# --- watchlist triage -------------------------------------------------------
# Union the hand-maintained list with every C_Namespace.Function the addon actually calls,
# so symbols added to Api/ are covered without anyone remembering to edit watchlist.txt.
{
	grep -vE '^\s*(#|$)' "$WATCHLIST" 2>/dev/null
	grep -rhoE '\bC_[A-Za-z]+\.[A-Za-z_]+' "$ROOT/LegacyNext" 2>/dev/null | sed 's/.*\.//'
} | sort -u > "$OUT/symbols.txt"

# Match hunks, not lines. A changed function signature adds a line like
#   + { Name = "spent", Type = "number" },
# which never names the function it belongs to, so a line-level grep for
# GetTraitCurrencyForAchievement misses the exact change we most need to catch. Wide context
# plus whole-hunk matching attributes that line to its enclosing entry. It over-matches when
# one hunk spans two entries, which is the right direction to fail for a triage filter.
git -C "$VENDOR" diff -U30 "$OLD" "$NEW" -- "${PATHS[@]}" 2>/dev/null > "$OUT/triage.diff"

: > "$OUT/watchlist.txt"
while IFS= read -r sym; do
	[[ -z "$sym" ]] && continue
	hits="$(awk -v sym="$sym" '
		function flush() {
			if (changed && index(hunk, sym)) printf "--- %s\n%s", file, hunk
			hunk = ""; changed = 0
		}
		/^diff --git/ { flush(); file = substr($0, index($0, " b/") + 3); next }
		/^@@/         { flush(); next }
		{
			if ($0 ~ /^[+-]/ && $0 !~ /^(\+\+\+|---)/) changed = 1
			# Keep the changed lines, plus the entry names that give them meaning.
			if ($0 ~ /^[+-]/ || index($0, "Name = \"") || index($0, sym)) hunk = hunk $0 "\n"
		}
		END { flush() }
	' "$OUT/triage.diff" 2>/dev/null || true)"
	if [[ -n "$hits" ]]; then
		# Sibling symbols share a hunk — all six Legacy constants live in one table, so a
		# naive loop prints the same block six times. Group by block content instead.
		# Done with files rather than an associative array: macOS ships bash 3.2.
		h="$(printf '%s' "$hits" | shasum | cut -c1-12)"
		mkdir -p "$OUT/.blocks"
		printf '%s\n' "$hits" > "$OUT/.blocks/$h.block"
		printf '%s\n' "$sym" >> "$OUT/.blocks/$h.syms"
	fi
done < "$OUT/symbols.txt"

: > "$OUT/watchlist.txt"
for b in "$OUT"/.blocks/*.block; do
	[[ -e "$b" ]] || break
	{
		echo "### $(tr '\n' ' ' < "${b%.block}.syms" | sed 's/ $//')"
		cat "$b"
		echo
	} >> "$OUT/watchlist.txt"
done
rm -rf "$OUT/.blocks"

# Constant values deserve their own file: a changed number is the one failure mode that
# produces wrong data rather than a Lua error.
git -C "$VENDOR" diff "$OLD" "$NEW" \
	-- 'Interface/AddOns/Blizzard_APIDocumentationGenerated/LegacyConstantsDocumentation.lua' \
	2>/dev/null > "$OUT/constants.diff"

if [[ -s "$OUT/watchlist.txt" ]]; then
	say "WATCHLIST_HIT: symbols LegacyNext depends on appear in this diff."
	say "  Read $OUT/watchlist.txt — that is the triaged view."
	grep '^### ' "$OUT/watchlist.txt" | sed 's/^### /  /' | tee -a "$SUMMARY"
else
	say "no watched symbol appears in the diff. The changed files are adjacent, not ours."
fi
say ""
[[ -s "$OUT/constants.diff" ]] && { say "CONSTANTS_CHANGED: LegacyConstantsDocumentation.lua moved. Read $OUT/constants.diff."; say ""; }

say "artifacts:"
say "  summary.txt     this file"
say "  namestatus.txt  every changed file, A/M/D"
say "  full.diff       the complete diff ($(wc -l < "$OUT/full.diff" | tr -d ' ') lines)"
say "  watchlist.txt   only the hunks touching symbols we call"
say "  constants.diff  LegacyConstantsDocumentation.lua alone"
say ""
say "next: read the artifacts, then scripts/bump.sh --apply $NEW"
