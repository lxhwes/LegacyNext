#!/usr/bin/env bash
# Everything CI will check, plus the project-specific rules CI cannot express.
#
# CI runs `luacheck LegacyNext spec` and `busted` on every push, so a skipped lint here
# becomes a red PR there. The greps below cover the CLAUDE.md hard constraints, which are
# invisible to both tools: a hardcoded achievement ID lints clean and passes every test, and
# only stops working when Blizzard renumbers it during beta.
#
# Usage: precommit.sh [--staged]
#   --staged: check only staged files for the pattern rules (lint and tests always run whole)
#
# Exit: 0 clean | 1 hard failure | 2 warnings worth a human glance | 3 toolchain missing
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

STAGED=0
[ "${1:-}" = "--staged" ] && STAGED=1

fails=0
warns=0

# Explicit template: bare `mktemp -d` ignores TMPDIR on macOS.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/lgn.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

section() { printf '\n== %s ==\n' "$1"; }
fail() { echo "FAIL $*"; fails=$((fails + 1)); }
warn() { echo "WARN $*"; warns=$((warns + 1)); }

# --- Toolchain -------------------------------------------------------------------------
# Project-local by design: Homebrew has no lua@5.1, so tools/ holds PUC Lua 5.1.5 built by
# hererocks. It is gitignored, so a fresh clone has none of it.
LUACHECK=""
BUSTED=""
for candidate in "./tools/lua51/bin/luacheck" "luacheck"; do
	command -v "$candidate" >/dev/null 2>&1 && { LUACHECK="$candidate"; break; }
done
for candidate in "./tools/lua51/bin/busted" "busted"; do
	command -v "$candidate" >/dev/null 2>&1 && { BUSTED="$candidate"; break; }
done

section "Lint"
if [ -n "$LUACHECK" ]; then
	"$LUACHECK" LegacyNext spec || fail "luacheck"
else
	warn "luacheck not found — see CLAUDE.md Toolchain. CI will run it regardless."
fi

section "Tests"
if [ -n "$BUSTED" ]; then
	"$BUSTED" || fail "busted"
else
	warn "busted not found — see CLAUDE.md Toolchain. CI will run it regardless."
fi

# --- What files are in play ------------------------------------------------------------
if [ "$STAGED" -eq 1 ]; then
	mapfile -t CHANGED < <(git diff --cached --name-only --diff-filter=ACMR)
else
	mapfile -t CHANGED < <(git status --porcelain | awk '{print $NF}')
fi

addon_files() {
	for file in "${CHANGED[@]:-}"; do
		case "$file" in LegacyNext/*.lua) [ -f "$file" ] && echo "$file" ;; esac
	done
}

section "Hard constraints"

ADDON=()
while IFS= read -r line; do [ -n "$line" ] && ADDON+=("$line"); done < <(addon_files)

if [ "${#ADDON[@]}" -eq 0 ]; then
	echo "no changed .lua under LegacyNext/ — pattern checks skipped"
else
	# Match against code, not comments. This project documents its own constraints in prose
	# right next to the code that honours them ("Never SetAchievementSearchString: that is
	# global client state"), so a grep over raw lines flags the comment explaining the rule as
	# a violation of it. A gate that cries wolf on correct code is one people learn to ignore.
	#
	# Line numbers survive because the comment text is blanked in place rather than deleted.
	# A `--` inside a string literal is blanked too; that is a known and accepted imprecision
	# in a heuristic whose job is to raise a human's attention, not to parse Lua.
	STRIPPED=()
	for file in "${ADDON[@]}"; do
		out="$TMP/$(echo "$file" | tr '/' '_')"
		sed 's/--.*$//' "$file" > "$out"
		echo "$file" > "$out.name"
		STRIPPED+=("$out")
	done

	# Report a hit against its real path and line rather than the temp copy's.
	report() {
		local pattern="$1" label="$2" severity="$3" hit=0
		for stripped in "${STRIPPED[@]}"; do
			local name
			name="$(cat "$stripped.name")"
			local matches
			matches="$(grep -nE "$pattern" "$stripped" || true)"
			if [ -n "$matches" ]; then
				hit=1
				echo "$matches" | sed "s|^|        $name:|"
			fi
		done
		if [ "$hit" -eq 1 ]; then
			if [ "$severity" = "fail" ]; then fail "$label"; else warn "$label"; fi
		fi
	}

	# Read-only trait access, always. Blizzard's own UI calls these; we do not.
	report 'ResetTree|PurchaseRank|RefundRank|CommitConfig|StageTrait|RemoveTrait|RollbackConfig' \
		"write/mutating trait API in LegacyNext/ (CLAUDE.md: read-only, always)" fail

	# Global state shared with Blizzard's Achievement UI, not a private filter.
	report 'SetAchievementSearchString|GetNumFilteredAchievements|GetFilteredAchievementID' \
		"filtered-achievement API in LegacyNext/ — enumerate categories directly instead" fail

	# Blizzard_LegacySystem is load-on-demand and every C API we need works without it.
	report 'LoadAddOn' "LoadAddOn in LegacyNext/ (docs/status.md: decided against)" fail

	# Feature-detect everything: this client reports Mainline on interface 16001, so branching
	# on either of these gives the wrong answer. Reading WOW_PROJECT_ID to *report* it in a
	# dump is fine and the addon really does that — only a comparison is gating, so the match
	# requires the value to be under test rather than merely read.
	report '(WOW_PROJECT_ID|GetBuildInfo\(\))[^\n]*(==|~=|>=|<=|<|>)|(if|elseif|and|or)[^\n]*(WOW_PROJECT_ID|GetBuildInfo\(\))|interface[[:space:]]*[<>=]' \
		"client/interface gating in LegacyNext/ — feature-detect the function instead" fail

	# Heuristic, not proof: IDs churn through beta, so a bare 4+ digit literal in addon code is
	# usually a hardcoded achievement, category or criteria ID. Constants, fallbacks and the
	# prose around them are the legitimate case.
	for stripped in "${STRIPPED[@]}"; do
		name="$(cat "$stripped.name")"
		suspects="$(grep -nE '(^|[^[:alnum:]_.])[0-9]{4,}' "$stripped" \
			| grep -viE 'fallback|LegacyConsts|LEGACY_|ACHIEVEMENT_FLAGS|Interface:|version' || true)"
		if [ -n "$suspects" ]; then
			warn "$name: numeric literal(s) that may be a hardcoded ID — confirm each is not an achievement, category or criteria ID:"
			echo "$suspects" | sed "s|^|        $name:|"
		fi
	done

	# A WoW global reached from Model/ is the architecture violation that costs the test suite,
	# since Model/ specs run with no WoW environment at all.
	for stripped in "${STRIPPED[@]}"; do
		name="$(cat "$stripped.name")"
		case "$name" in
			LegacyNext/Model/*)
				if grep -nE '(^|[^[:alnum:]_.])(C_[A-Za-z]+|CreateFrame|GetAchievement|GetCategory|UIParent|Constants)' "$stripped" | sed "s|^|        $name:|"; then
					fail "$name: WoW global in Model/ (Model/ must be pure Lua)"
				fi
				;;
			LegacyNext/UI/*)
				if grep -nE 'ns\.Api\.' "$stripped" | sed "s|^|        $name:|"; then
					warn "$name: UI/ reaching into Api/ — UI talks to Model, never to Api directly"
				fi
				;;
		esac
	done
fi

section "Staging"
for file in "${CHANGED[@]:-}"; do
	case "$file" in
		tools/*|.release/*|__pycache__/*|*.luacheckcache)
			fail "$file should not be committed (gitignored build output)" ;;
		vendor/*)
			fail "$file: the Blizzard checkout and its PINS.md live in \$WOW_FOREVER_SRC now, not in this repo" ;;
		.claude/skill-evals/*)
			fail "$file: eval run artifacts are gitignored; only evals/ specs are committed" ;;
	esac
done

# A fixture with no provenance cannot later be told apart from an invention, which is the
# whole reason the fixture rule exists.
for file in "${CHANGED[@]:-}"; do
	case "$file" in
		spec/fixtures/*.lua)
			[ -f "$file" ] || continue
			if ! grep -qiE 'source|captured|build' "$file"; then
				fail "$file: fixture has no provenance header (see fixture-intake)"
			fi
			;;
	esac
done

# Any in-game script must survive newline stripping before a human pastes it.
for file in "${CHANGED[@]:-}"; do
	case "$file" in
		docs/ingame-commands.md)
			# forever-check-script comes from the forever-tools plugin and is on PATH in a
			# session where the plugin is enabled.
			gate="$(command -v forever-check-script || true)"
			if [ -n "$gate" ]; then
				echo "running the in-game script parse gate"
				"$gate" "$file" || warn "in-game script gate reported problems (see above)"
			else
				warn "docs/ingame-commands.md changed but forever-check-script is not on PATH (forever-tools plugin not enabled?)"
			fi
			;;
	esac
done

printf '\n---\n'
echo "$fails failure(s), $warns warning(s)."
if [ "$fails" -gt 0 ]; then exit 1; fi
if [ -z "$LUACHECK" ] || [ -z "$BUSTED" ]; then exit 3; fi
if [ "$warns" -gt 0 ]; then exit 2; fi
exit 0
