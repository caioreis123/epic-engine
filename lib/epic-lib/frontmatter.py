#!/usr/bin/env python3
"""Reads Markdown frontmatter without requiring PyYAML.

Supports the subset used by epics: scalar `key: value` and string lists
(`key:` followed by `  - "..."` lines).
"""
import json
import sys

DELIMITER = "---"
CONCLUSION_FIELDS = ("value", "at", "basis", "reason")


def _strip_quotes(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def parse_frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != DELIMITER:
        return {}

    fields = {}
    current_list_key = None
    for line in lines[1:]:
        if line.strip() == DELIMITER:
            break
        if line.startswith((" ", "\t")) and line.strip().startswith("- "):
            if current_list_key:
                fields[current_list_key].append(_strip_quotes(line.strip()[2:]))
            continue
        if ":" not in line:
            continue
        key, _, raw_value = line.partition(":")
        key = key.strip()
        value = raw_value.strip()
        if value == "":
            fields[key] = []
            current_list_key = key
        else:
            fields[key] = _strip_quotes(value)
            current_list_key = None
    return fields


def last_conclusion(conclusions):
    parsed = {field: "" for field in CONCLUSION_FIELDS}
    parsed["reviewed"] = len(conclusions) > 1
    if not conclusions:
        return parsed
    parts = [part.strip() for part in conclusions[-1].split("|", len(CONCLUSION_FIELDS) - 1)]
    for index, field in enumerate(CONCLUSION_FIELDS):
        if index < len(parts):
            parsed[field] = parts[index]
    return parsed


def read(path):
    with open(path, encoding="utf-8") as handle:
        fields = parse_frontmatter(handle.read())
    conclusions = fields.get("conclusions") or []
    if isinstance(conclusions, str):
        conclusions = [conclusions]
    fields["conclusions"] = conclusions
    fields["last_conclusion"] = last_conclusion(conclusions)
    return fields


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: frontmatter.py <file.md>", file=sys.stderr)
        sys.exit(2)
    print(json.dumps(read(sys.argv[1]), ensure_ascii=False))
