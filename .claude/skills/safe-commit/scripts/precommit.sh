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
	# Read-only trait access, always. Blizzard's own UI calls these; we do not.
	if grep -nE 'ResetTree|PurchaseRank|RefundRank|CommitConfig|StageTrait|RemoveTrait|RollbackConfig' "${ADDON[@]}"; then
		fail "write/mutating trait API in LegacyNext/ (CLAUDE.md: read-only, always)"
	fi

	# Global state shared with Blizzard's Achievement UI, not a private filter.
	if grep -nE 'SetAchievementSearchString|GetNumFilteredAchievements|GetFilteredAchievementID' "${ADDON[@]}"; then
		fail "filtered-achievement API in LegacyNext/ — enumerate categories directly instead"
	fi

	# Blizzard_LegacySystem is load-on-demand and every C API we need works without it.
	if grep -n 'LoadAddOn' "${ADDON[@]}"; then
		fail "LoadAddOn in LegacyNext/ (docs/status.md: decided against)"
	fi

	# Feature-detect everything: this client reports Mainline on interface 16001, so both of
	# these tests give the wrong answer here.
	if grep -nE 'WOW_PROJECT_ID|GetBuildInfo\(\)|interface[[:space:]]*[<>=]' "${ADDON[@]}"; then
		fail "client/interface gating in LegacyNext/ — feature-detect the function instead"
	fi

	# Heuristic, not proof: IDs churn through beta, so a bare 4+ digit literal in addon code
	# is usually a hardcoded achievement, category or criteria ID. Lines that name a constant
	# or a fallback are the legitimate case.
	suspects="$(grep -nE '(^|[^[:alnum:]_.])[0-9]{4,}' "${ADDON[@]}" \
		| grep -viE 'fallback|LegacyConsts|LEGACY_|Interface:|version' || true)"
	if [ -n "$suspects" ]; then
		warn "numeric literal(s) that may be a hardcoded ID — confirm each is not an achievement, category or criteria ID:"
		echo "$suspects" | sed 's/^/        /'
	fi

	# A WoW global reached from Model/ is the architecture violation that costs the test suite,
	# since Model/ specs run with no WoW environment at all.
	for file in "${ADDON[@]}"; do
		case "$file" in
			LegacyNext/Model/*)
				if grep -nE '(^|[^[:alnum:]_.])(C_[A-Za-z]+|CreateFrame|GetAchievement|GetCategory|UIParent|Constants)' "$file"; then
					fail "$file: WoW global in Model/ (Model/ must be pure Lua)"
				fi
				;;
			LegacyNext/UI/*)
				if grep -nE 'ns\.Api\.' "$file"; then
					warn "$file: UI/ reaching into Api/ — UI talks to Model, never to Api directly"
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
			[ "$file" = "vendor/PINS.md" ] || \
				fail "$file: the vendored checkout is reference material, only PINS.md is tracked" ;;
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
			gate=".claude/skills/ingame-script/scripts/check_script.sh"
			if [ -x "$gate" ]; then
				echo "running the in-game script parse gate"
				"$gate" "$file" || warn "in-game script gate reported problems (see above)"
			else
				warn "docs/ingame-commands.md changed but $gate is missing"
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
