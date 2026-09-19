#!/usr/bin/env python3
"""Turn a paste from the live client into a Lua fixture, without editing the data.

The paste is the only evidence we have that a fixture is real rather than invented, so this
script is deliberately narrow: it parses the `== SECTION ==` / header / semicolon-row shape
the in-game scripts emit, types the values, keeps the raw text verbatim in the file, and
refuses to write anything without provenance.

Usage:
  dump_to_fixture.py PASTE --out spec/fixtures/NAME.lua \\
      --source "script 1, docs/ingame-commands.md" \\
      --date 2026-09-18 --build 1.60.1.69913 --pin 70ef1b2 \\
      --character "fresh level 1, no points spent" \\
      [--section CRITERIA_PROGRESSBAR] [--stdout]

Exit: 0 wrote | non-zero on bad input, missing provenance, or nothing parseable
"""

import argparse
import os
import re
import sys

SECTION_RE = re.compile(r"^==\s*(.+?)\s*==$")
KV_RE = re.compile(r"^([A-Za-z_][\w()]*)\s*=\s*(.*)$")
IDENT_RE = re.compile(r"^[A-Za-z_]\w*$")
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if",
    "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}


def lua_string(value):
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )
    return '"' + escaped + '"'


def lua_key(name):
    if IDENT_RE.match(name) and name not in LUA_KEYWORDS:
        return name
    return "[" + lua_string(name) + "]"


def long_bracket(text):
    """Pick a long-bracket level that cannot be closed by the text itself."""
    level = 0
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[", "]" + eq + "]"


def typed(raw, force_string=False):
    """Convert one field, preserving the distinction between absent and empty.

    The client prints absent values as the literal string `nil`; keeping that as a Lua nil
    means the key is simply absent from the row, which is what the API would have given us.
    Everything that is not unambiguously a number or boolean stays a string — guessing here
    would be editing the evidence.
    """
    text = raw.strip()
    if force_string and text != "nil":
        return text, lua_string(raw)
    if text == "nil":
        return None, "nil"
    if text == "true":
        return True, "true"
    if text == "false":
        return False, "false"
    if re.fullmatch(r"-?\d+", text):
        return int(text), str(int(text))
    if re.fullmatch(r"-?\d+\.\d+", text):
        return float(text), text
    return text, lua_string(raw)


def parse(text):
    """Split a paste into ordered sections of rows and/or key-values."""
    sections = []
    current = {"name": "UNSECTIONED", "columns": None, "rows": [], "values": [], "other": []}

    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue

        header = SECTION_RE.match(stripped)
        if header:
            if current["rows"] or current["values"] or current["other"]:
                sections.append(current)
            current = {
                "name": header.group(1),
                "columns": None,
                "rows": [],
                "values": [],
                "other": [],
            }
            continue

        if ";" in stripped:
            fields = stripped.split(";")
            if current["columns"] is None:
                current["columns"] = [f.strip() for f in fields]
            else:
                current["rows"].append(fields)
            continue

        # The capture scripts sometimes put several key=value pairs on one line, separated
        # by a run of spaces. Split on that first, and only accept the split if every part
        # is itself a key=value — otherwise a value containing spaces would be shredded.
        parts = re.split(r"\s{2,}", stripped)
        matches = [KV_RE.match(part) for part in parts]
        if len(parts) > 1 and all(matches):
            for match in matches:
                current["values"].append((match.group(1), match.group(2)))
            continue

        kv = KV_RE.match(stripped)
        if kv:
            current["values"].append((kv.group(1), kv.group(2)))
            continue

        current["other"].append(stripped)

    if current["rows"] or current["values"] or current["other"] or current["columns"]:
        sections.append(current)

    return sections


def section_key(name):
    return re.sub(r"[^\w]+", "_", name).strip("_").upper()


def emit(sections, meta, raw_text, string_columns=frozenset()):
    out = []
    out.append("-- Captured client data. Do not edit the values in this file: it is evidence,")
    out.append("-- not source. If something looks wrong, re-run the command and re-capture.")
    out.append("--")
    for key in ("source", "captured", "build", "pin", "character", "notes"):
        if meta.get(key):
            out.append("-- {:<10} {}".format(key + ":", meta[key]))
    out.append("--")
    if meta.get("string_columns"):
        out.append("-- Forced to string (the paste cannot tell 0 from \"0\"): {}".format(
            meta["string_columns"]))
    out.append("-- Pipes were replaced with '!' by the capture script, and WoW colour codes")
    out.append("-- stripped, so any '!' may have been a '|' in the client's own text.")
    out.append("")
    out.append("return {")
    out.append("\tmeta = {")
    for key in ("source", "captured", "build", "pin", "character", "notes"):
        if meta.get(key):
            out.append("\t\t{} = {},".format(key, lua_string(meta[key])))
    out.append("\t},")
    out.append("")
    out.append("\tsections = {")

    for section in sections:
        key = section_key(section["name"])
        out.append("\t\t{} = {{".format(lua_key(key)))
        out.append("\t\t\tlabel = {},".format(lua_string(section["name"])))

        if section["columns"] and section["rows"]:
            columns = section["columns"]
            out.append("\t\t\tcolumns = {{{}}},".format(
                ", ".join(lua_string(c) for c in columns)
            ))
            out.append("\t\t\trows = {")
            for fields in section["rows"]:
                if len(fields) != len(columns):
                    out.append(
                        "\t\t\t\t-- WIDTH MISMATCH: {} field(s) against {} column(s), kept raw"
                        .format(len(fields), len(columns))
                    )
                    out.append("\t\t\t\t{{ raw = {} }},".format(lua_string(";".join(fields))))
                    continue
                parts = []
                for column, field in zip(columns, fields):
                    value, literal = typed(field, column in string_columns)
                    if value is None:
                        continue  # absent in the client's own output
                    parts.append("{} = {}".format(lua_key(column), literal))
                out.append("\t\t\t\t{{ {} }},".format(", ".join(parts)))
            out.append("\t\t\t},")
        elif section["columns"]:
            out.append("\t\t\tcolumns = {{{}}},".format(
                ", ".join(lua_string(c) for c in section["columns"])
            ))
            out.append("\t\t\trows = {},")

        if section["values"]:
            out.append("\t\t\tvalues = {")
            for name, raw in section["values"]:
                _, literal = typed(raw)
                out.append("\t\t\t\t{} = {},".format(lua_key(name), literal))
            out.append("\t\t\t},")

        if section["other"]:
            out.append("\t\t\tlines = {")
            for line in section["other"]:
                out.append("\t\t\t\t{},".format(lua_string(line)))
            out.append("\t\t\t},")

        out.append("\t\t},")

    out.append("\t},")
    out.append("")
    open_b, close_b = long_bracket(raw_text)
    out.append("\t-- The paste, verbatim. Kept so a transcription mistake above stays findable.")
    out.append("\traw = {}\n{}{},".format(open_b, raw_text.rstrip("\n"), close_b))
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paste", help="file holding the pasted client output, or - for stdin")
    parser.add_argument("--out", help="fixture path, e.g. spec/fixtures/criteria_shapes.lua")
    parser.add_argument("--stdout", action="store_true", help="print instead of writing")
    parser.add_argument("--source", required=True,
                        help='what produced it, e.g. "script 1, docs/ingame-commands.md"')
    parser.add_argument("--date", required=True, help="capture date, YYYY-MM-DD")
    parser.add_argument("--build", required=True, help='client build, e.g. 1.60.1.69913')
    parser.add_argument("--pin", help="vendor pin SHA in effect at capture")
    parser.add_argument("--character", required=True,
                        help='character state, e.g. "fresh level 1, no points spent"')
    parser.add_argument("--notes", help="anything odd about the capture")
    parser.add_argument("--string-col", action="append", default=[], metavar="COLUMN",
                        help="type this column as a string even when it looks numeric — the "
                             "paste cannot tell 0 from \"0\", and quantityString, charName "
                             "and name are strings in the API (repeatable)")
    parser.add_argument("--section", action="append",
                        help="keep only these sections (repeatable, matched on the key)")
    args = parser.parse_args()

    if not args.out and not args.stdout:
        parser.error("pass --out PATH or --stdout")

    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
        parser.error("--date must be YYYY-MM-DD: the fixture is only interpretable with one")

    raw_text = sys.stdin.read() if args.paste == "-" else open(args.paste).read()
    if not raw_text.strip():
        print("dump_to_fixture: empty paste, nothing to do", file=sys.stderr)
        return 2

    sections = parse(raw_text)
    if args.section:
        wanted = {section_key(s) for s in args.section}
        sections = [s for s in sections if section_key(s["name"]) in wanted]
    if not sections:
        print("dump_to_fixture: no sections parsed — check the paste survived intact",
              file=sys.stderr)
        return 2

    meta = {
        "string_columns": ", ".join(sorted(args.string_col)) or None,
        "source": args.source,
        "captured": args.date,
        "build": args.build,
        "pin": args.pin,
        "character": args.character,
        "notes": args.notes,
    }
    lua = emit(sections, meta, raw_text, frozenset(args.string_col))

    if args.stdout:
        sys.stdout.write(lua)
    else:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w") as handle:
            handle.write(lua)
        rows = sum(len(s["rows"]) for s in sections)
        print("wrote {} — {} section(s), {} row(s)".format(args.out, len(sections), rows))
        print("Check the generated file against the paste before committing: the raw block at "
              "the bottom is what makes a transcription mistake findable.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
