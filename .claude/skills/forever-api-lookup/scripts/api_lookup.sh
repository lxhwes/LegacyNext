#!/usr/bin/env bash
# Look up one WoW API symbol in the vendored Forever branch.
#
# Prints, in order:
#   1. the pinned commit, so the citation can be reproduced
#   2. the generated API documentation entry, if one exists
#   3. every call site in Blizzard's own vendored UI code
#   4. a verdict line naming the evidence tier
#
# Usage:
#   scripts/api_lookup.sh C_Traits.GetTreeCurrencyInfo
#   scripts/api_lookup.sh GetAchievementCriteriaInfo
#   scripts/api_lookup.sh ACHIEVEMENT_EARNED
#   scripts/api_lookup.sh LEGACY_POINTS_TRAIT_CURRENCY_ID

set -uo pipefail

SYMBOL="${1:-}"
if [[ -z "$SYMBOL" ]]; then
	echo "usage: $(basename "$0") <Namespace.Function | Function | EVENT_NAME | CONSTANT_NAME>" >&2
	exit 64
fi

# Walk up from the script to the repo root so the script works from any cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VENDOR="$ROOT/vendor/wow-ui-source"
UI="$VENDOR/Interface/AddOns"
DOCS="$UI/Blizzard_APIDocumentationGenerated"

if [[ ! -d "$DOCS" ]]; then
	echo "FATAL: vendored source missing at $VENDOR" >&2
	echo "Recreate it with the sparse-checkout recipe in vendor/PINS.md, then retry." >&2
	exit 69
fi

# Split "C_Traits.GetTreeCurrencyInfo" into namespace + bare name. The generated docs
# store the namespace once per file, so searching for the bare name is what matches.
NAMESPACE=""
BARE="$SYMBOL"
if [[ "$SYMBOL" == *.* ]]; then
	NAMESPACE="${SYMBOL%%.*}"
	BARE="${SYMBOL##*.}"
fi

# Print the one documentation entry that starts at $2 in file $1. Entries are tab-indented
# and close on a line that is exactly two tabs + "},", which bounds one definition.
print_entry() {
	awk -v start="$2" '
		NR >= start - 3 { print NR ": " $0 }
		NR >= start && $0 ~ /^\t\t\},$/ { exit }
	' "$1"
}

PIN="$(git -C "$VENDOR" rev-parse HEAD 2>/dev/null || echo 'unknown')"
VERSION="$(cat "$VENDOR/version.txt" 2>/dev/null || echo 'unknown')"

echo "symbol:  $SYMBOL"
echo "pin:     $PIN  (version.txt $VERSION)"
echo

# --- Tier A: generated API documentation ------------------------------------
# Entries look like:   Name = "GetTreeCurrencyInfo",
# and the enclosing table closes on a line that is exactly two tabs + "},".
echo "=== [A] generated API doc ==="
DOC_HITS="$(grep -rn "Name = \"$BARE\"," "$DOCS" 2>/dev/null || true)"

if [[ -z "$DOC_HITS" ]]; then
	echo "(no entry — this symbol is undocumented in the generated docs)"
else
	while IFS= read -r hit; do
		file="${hit%%:*}"
		rest="${hit#*:}"
		line="${rest%%:*}"

		# Namespace is declared once, near the top of each doc file.
		ns="$(grep -m1 'Namespace = ' "$file" | sed 's/.*Namespace = "\(.*\)".*/\1/' || true)"
		sys="$(grep -m1 'Name = ' "$file" | sed 's/.*Name = "\(.*\)".*/\1/' || true)"

		echo "--- ${file#"$ROOT/"}:$line   [system: ${sys:-?}${ns:+, namespace: $ns}]"
		if [[ -n "$NAMESPACE" && -n "$ns" && "$NAMESPACE" != "$ns" ]]; then
			echo "    NOTE: you asked for $NAMESPACE.$BARE but this entry is $ns.$BARE."
		fi
		ENTRY="$(print_entry "$file" "$line")"
		echo "$ENTRY"
		echo

		# A return of Type/InnerType "TreeCurrencyInfo" is useless without the field list,
		# so resolve every non-primitive type the entry mentions. Chasing these by hand is
		# the step most often skipped, and skipping it is how invented field names get in.
		REFS="$(grep -oE '(Inner)?Type = "[A-Za-z][A-Za-z0-9_]*"' <<< "$ENTRY" \
			| sed 's/.*"\(.*\)"/\1/' \
			| grep -vxE 'number|string|bool|table|Function|Event|Structure|Enumeration|Constants|CallbackType|time_t|luaIndex|fileID|uiUnit|uiAddon|cstring|vector2|vector3|colorRGB|textureAtlas|BigUInteger|WOWMONEY|WOWGUID|size' \
			| sort -u || true)"
		for ref in $REFS; do
			refhit="$(grep -rn "Name = \"$ref\"," "$DOCS" 2>/dev/null | head -1 || true)"
			if [[ -n "$refhit" ]]; then
				rf="${refhit%%:*}"; rl="${refhit#*:}"; rl="${rl%%:*}"
				echo "    ~ resolves $ref -> ${rf#"$ROOT/"}:$rl"
				print_entry "$rf" "$rl" | sed 's/^/      /'
				echo
			else
				echo "    ~ $ref: referenced but NOT defined anywhere in the docs — flag it"
			fi
		done
	done <<< "$DOC_HITS"
fi

echo
# --- Tier B: Blizzard's own call sites ---------------------------------------
# The whole Interface tree is checked out (~348 addons), so a bare-name grep is noisy:
# GetCategoryInfo exists under half a dozen namespaces. When the caller supplied a
# namespace, match "Namespace.Function" and keep the bare-name hits in a separate bucket,
# because a hit under a different namespace is not evidence about this function at all.
echo "=== [B] Blizzard UI call sites ==="
if [[ -n "$NAMESPACE" ]]; then
	CALL_HITS="$(grep -rn --fixed-strings "$NAMESPACE.$BARE" "$UI" 2>/dev/null | grep -v "Blizzard_APIDocumentationGenerated/" || true)"
	OTHER_NS="$(grep -rn --fixed-strings "$BARE" "$UI" 2>/dev/null \
		| grep -v "Blizzard_APIDocumentationGenerated/" \
		| grep -v --fixed-strings "$NAMESPACE.$BARE" || true)"
else
	CALL_HITS="$(grep -rn --fixed-strings "$BARE" "$UI" 2>/dev/null | grep -v "Blizzard_APIDocumentationGenerated/" || true)"
	OTHER_NS=""
fi

# Rank by relevance so the most useful call sites survive a truncated read: our own two
# addons first, then the achievement UI, then the rest of the tree.
print_bucket() {
	local label="$1" pattern="$2" cap="$3" hits n
	hits="$(grep -E "$pattern" <<< "$CALL_HITS" || true)"
	[[ -z "$hits" ]] && return
	n="$(wc -l <<< "$hits" | tr -d ' ')"
	echo "-- $label ($n)"
	while IFS= read -r hit; do
		[[ -z "$hit" ]] && continue
		local flavour=""
		case "${hit%%:*}" in
			*/Blizzard_AchievementUI/Cata/*)     flavour="  <-- CATA FLAVOUR: wrong era, do not cite" ;;
			*/Blizzard_AchievementUI/Mainline/*) flavour="  <-- Mainline flavour: what Forever loads" ;;
		esac
		echo "   ${hit#"$ROOT/"}$flavour"
	done <<< "$(head -n "$cap" <<< "$hits")"
	[[ "$n" -gt "$cap" ]] && echo "   ... $((n - cap)) more suppressed"
	echo
}

if [[ -z "$CALL_HITS" ]]; then
	echo "(no call sites anywhere in Interface/)"
else
	print_bucket "Legacy addons — closest to our use case" '/Blizzard_Legacy' 40
	print_bucket "Achievement UI — mind the flavour" '/Blizzard_AchievementUI/' 20
	REST="$(grep -vE '/Blizzard_Legacy|/Blizzard_AchievementUI/' <<< "$CALL_HITS" || true)"
	if [[ -n "$REST" ]]; then
		RN="$(wc -l <<< "$REST" | tr -d ' ')"
		echo "-- Rest of Interface/ ($RN)"
		while IFS= read -r hit; do
			[[ -z "$hit" ]] && continue
			echo "   ${hit#"$ROOT/"}"
		done <<< "$(head -8 <<< "$REST")"
		[[ "$RN" -gt 8 ]] && echo "   ... $((RN - 8)) more suppressed; re-grep if you need them"
		echo
	fi
fi

if [[ -n "$OTHER_NS" ]]; then
	ON="$(wc -l <<< "$OTHER_NS" | tr -d ' ')"
	echo "-- same bare name, DIFFERENT namespace ($ON) — not evidence about $SYMBOL"
	while IFS= read -r hit; do
		[[ -z "$hit" ]] && continue
		echo "   ${hit#"$ROOT/"}"
	done <<< "$(head -4 <<< "$OTHER_NS")"
	[[ "$ON" -gt 4 ]] && echo "   ... $((ON - 4)) more"
fi

echo
# --- Read-only guard ----------------------------------------------------------
# Blizzard's own UI calls the mutating trait APIs; LegacyNext must not. Finding a tidy
# call site is exactly how a write API sneaks in, so name the risk at lookup time.
case "$BARE" in
	ResetTree|PurchaseRank|RefundRank|CommitConfig|RollbackConfig|StageConfig|\
	SetSelection|ClearCascadeRepurchaseHistory|SetConfigUseStrictPurchaseValidation)
		echo "=== STOP: mutating API ==="
		echo "$BARE changes game state. LegacyNext is read-only against the trait system"
		echo "(see CLAUDE.md, Hard constraints). Blizzard calling it does not license us to."
		echo "Do not add this to Api/. If the task seems to need it, stop and ask Alex."
		echo
		;;
	Set*|Purchase*|Commit*|Refund*|Reset*|Remove*|Delete*|Apply*)
		echo "=== CHECK: write-shaped name ==="
		echo "$BARE reads like a mutation. Confirm from the doc entry above that it only"
		echo "returns data before putting it in Api/; if it writes, it is out of bounds."
		echo
		;;
esac

# --- Verdict ------------------------------------------------------------------
echo "=== verdict ==="
if [[ -n "$DOC_HITS" && -n "$CALL_HITS" ]]; then
	echo "TIER A+B — documented and used by Blizzard. Cite both; trust the doc for the signature."
elif [[ -n "$DOC_HITS" ]]; then
	echo "TIER A — documented, but nothing in the vendored UI calls it. The signature is"
	echo "reliable; real-world argument values are not. Prefer a fixture before relying on it."
elif [[ -n "$CALL_HITS" ]]; then
	echo "TIER B — undocumented, but Blizzard calls it. Read the call sites for the return"
	echo "order; a doc-less global is normal for FrameXML functions, not a red flag."
else
	if [[ -n "$NAMESPACE" ]]; then
		echo "TIER C — ABSENT, and for a namespaced symbol that is STRONG evidence. The"
		echo "generated docs are a complete dump of the client's API (639 files, 285"
		echo "namespaces), so $NAMESPACE.$BARE almost certainly does not exist under that"
		echo "name. Before reporting back, look for the real API that does the job — the"
		echo "capability is usually there under a different namespace."
	else
		echo "TIER C — ABSENT, but for a bare global that is WEAK evidence. Only four addons"
		echo "are vendored, so a FrameXML global called from elsewhere in the UI looks"
		echo "identical to one that does not exist. Do not assert it is fake."
	fi
	echo "Either way: invent no shape. Flag [unverified] and ask Alex for a /dump."
fi
