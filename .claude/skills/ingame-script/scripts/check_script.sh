#!/usr/bin/env bash
# Verify an in-game script survives the paste path before a human ever sees it.
#
# Paste paths strip newlines, so every block is parsed twice: as written, and with its
# newlines DELETED. Deletion rather than space-substitution is deliberate — it is the worst
# case and the one that produced the real error `malformed number near '2802local'`.
#
# Usage: check_script.sh [--dry-run] <file.md | file.lua> [...]
#   .md files: every ```lua fenced block is checked, reported by its line number.
#   --dry-run: run every check except the parse, for environments with no Lua toolchain.
#
# Exit: 0 clean | 1 hard failure | 2 warnings only | 3 cannot verify (no luac)
set -uo pipefail

DRY_RUN=0
FILES=()
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY_RUN=1 ;;
		-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
		*) FILES+=("$arg") ;;
	esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
	echo "usage: check_script.sh [--dry-run] <file.md | file.lua> [...]" >&2
	exit 1
fi

# Project toolchain first: it is the 5.1.5 interpreter the addon actually targets, and a
# 5.4 or LuaJIT parser accepts syntax the client would reject.
LUAC=""
for candidate in "${LUAC_OVERRIDE:-}" "./tools/lua51/bin/luac" "luac5.1" "luac"; do
	[ -z "$candidate" ] && continue
	if command -v "$candidate" >/dev/null 2>&1; then LUAC="$candidate"; break; fi
done

if [ -z "$LUAC" ] && [ "$DRY_RUN" -eq 0 ]; then
	cat >&2 <<'MSG'
check_script.sh: no luac found, so the parse gate cannot run.

A gate that silently skips is worse than no gate — a script that fails to parse costs a
whole round trip through a human. Do one of:

  * build the toolchain (CLAUDE.md, Toolchain):
      python3 -m venv tools/venv && tools/venv/bin/pip install hererocks &&
      tools/venv/bin/hererocks tools/lua51 --lua 5.1 --luarocks latest
  * point at an existing one:  LUAC_OVERRIDE=/path/to/luac check_script.sh ...
  * run --dry-run for the non-parse checks only, and say in your handover that the block
    is UNPARSED so the next session knows it still needs the gate.
MSG
	exit 3
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Write APIs are forbidden in the addon (CLAUDE.md, Hard constraints) and the same rule holds
# in a probe: a script that spends a point or stages a change cannot be re-run, and it is
# Alex's character, not a fixture. SetAchievementSearchString is here for a different reason —
# it is global state shared with Blizzard's Achievement UI, so probing with it changes what
# his UI shows afterwards.
WRITE_APIS='ResetTree|PurchaseRank|RefundRank|CommitConfig|StageTrait|RemoveTrait|SetSelection|RollbackConfig|SetAchievementSearchString|LoadAddOn'

fails=0
warns=0
blocks=0

check_block() {
	local src="$1" label="$2"
	blocks=$((blocks + 1))
	local ok=1

	# A `--` comment is the nastier of the two flattening failures: it swallows the rest of
	# the script and can come back as a partial result rather than an error.
	if grep -n -- '--' "$src" >/dev/null 2>&1; then
		echo "FAIL $label: '--' found. Flattened, it comments out the rest of the script."
		grep -n -- '--' "$src" | sed 's/^/        /'
		ok=0
	fi

	if grep -nE "$WRITE_APIS" "$src" >/dev/null 2>&1; then
		echo "FAIL $label: write/global-state API in a read-only probe."
		grep -nE "$WRITE_APIS" "$src" | sed 's/^/        /'
		ok=0
	fi

	# Warning only: the flatten parse catches the dangerous juxtapositions (`2802local`) but
	# not the harmless ones (`end local`), and the rule is to terminate every statement so
	# that a later edit cannot turn a harmless one into a dangerous one.
	local unterminated
	unterminated="$(grep -nE '[^[:space:]]$' "$src" \
		| grep -vE ';$|[[:space:]]*(then|do|else|repeat)$|[{(,]$|[-+*/.=<>~]$|^[0-9]+:[[:space:]]*$' \
		|| true)"
	if [ -n "$unterminated" ]; then
		echo "WARN $label: statement(s) not semicolon-terminated:"
		echo "$unterminated" | sed 's/^/        /'
		warns=$((warns + 1))
	fi

	if [ -n "$LUAC" ]; then
		if ! "$LUAC" -p "$src" 2>"$TMP/err"; then
			echo "FAIL $label: does not parse as written."
			sed 's/^/        /' "$TMP/err"
			ok=0
		fi
		tr -d '\n' < "$src" > "$TMP/flat.lua"
		if ! "$LUAC" -p "$TMP/flat.lua" 2>"$TMP/err"; then
			echo "FAIL $label: does not parse with newlines stripped — this is how it may arrive."
			sed 's/^/        /' "$TMP/err"
			ok=0
		fi
	else
		echo "SKIP $label: parse not run (--dry-run). Block is UNPARSED."
	fi

	if [ "$ok" -eq 1 ]; then
		echo "ok   $label"
	else
		fails=$((fails + 1))
	fi
}

for file in "${FILES[@]}"; do
	if [ ! -f "$file" ]; then
		echo "FAIL $file: no such file"
		fails=$((fails + 1))
		continue
	fi

	case "$file" in
		*.md)
			# Extract every ```lua fenced block, keeping the line number it starts on so a
			# failure points back at the source rather than at a temp file.
			awk -v dir="$TMP" '
				/^```lua[[:space:]]*$/ && !inblock { inblock = 1; n++; start = NR; next }
				/^```[[:space:]]*$/ && inblock { inblock = 0; print n":"start; next }
				inblock { print > (dir "/block" n ".lua") }
			' "$file" > "$TMP/index"
			if [ ! -s "$TMP/index" ]; then
				echo "WARN $file: no \`\`\`lua blocks found"
				warns=$((warns + 1))
				continue
			fi
			while IFS=: read -r n start; do
				check_block "$TMP/block$n.lua" "$file block $n (line $start)"
			done < "$TMP/index"
			;;
		*)
			check_block "$file" "$file"
			;;
	esac
done

echo "---"
echo "$blocks block(s) checked, $fails failed, $warns warning(s)."

if [ "$fails" -gt 0 ]; then exit 1; fi
if [ -z "$LUAC" ]; then exit 3; fi
if [ "$warns" -gt 0 ]; then exit 2; fi
exit 0
