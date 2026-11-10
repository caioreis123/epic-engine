#!/usr/bin/env python3
"""Validates file:line citations in an epic dossier against real repository code.

Usage: citations.py <epic-dir> <repos-root>

Never modifies files: reports MISSING, SHORTENED, and AMBIGUOUS citations.
Always exits 0: it is an informational report, not a blocking gate.
"""
import os
import pathlib
import re
import subprocess
import sys

CODE_EXTS = (
    "js", "jsx", "mjs", "cjs", "ts", "tsx", "py", "go", "rb", "java", "kt",
    "graphql", "gql", "json", "yaml", "yml", "sh", "bash", "sql", "tf", "css", "scss",
)
CITATION_RE = re.compile(
    r"(?P<path>[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:" + "|".join(CODE_EXTS) + r")):"
    r"(?P<start>\d+)(?:-(?P<end>\d+))?"
)
SKIP_DIRS = {".git", "node_modules", ".next", "dist", "build", "__pycache__", ".venv"}
STATUS_WIDTH = 12


def citations(epic_dir):
    for md in sorted(epic_dir.rglob("*.md")):
        try:
            text = md.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for match in CITATION_RE.finditer(line):
                start = int(match.group("start"))
                end = int(match.group("end") or start)
                yield {
                    "origin": f"{md.relative_to(epic_dir)}:{lineno}",
                    "citation": match.group(0),
                    "path": match.group("path"),
                    "end": max(start, end),
                }


def tracked_files(repo):
    if (repo / ".git").exists():
        result = subprocess.run(
            ["git", "-C", str(repo), "ls-files", "-z"],
            capture_output=True, text=True, check=False,
        )
        if result.returncode == 0:
            return [rel for rel in result.stdout.split("\0") if rel]
    found = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            ext = name.rsplit(".", 1)[-1] if "." in name else ""
            if ext in CODE_EXTS:
                found.append(str(pathlib.Path(root, name).relative_to(repo)))
    return found


def repo_key(repo):
    if not (repo / ".git").exists():
        return repo.name
    for args in (["config", "--get", "remote.origin.url"], ["rev-parse", "--git-common-dir"]):
        result = subprocess.run(
            ["git", "-C", str(repo)] + args,
            capture_output=True, text=True, check=False,
        )
        key = result.stdout.strip()
        if result.returncode == 0 and key:
            if args[0] == "rev-parse":
                key = str(pathlib.Path(key if key.startswith("/") else repo / key).resolve())
            return key
    return repo.name


def canonical(names):
    without_dot = [name for name in names if "." not in name]
    return sorted(without_dot or names, key=lambda name: (len(name), name))[0]


def build_index(repos_root):
    if not repos_root.is_dir():
        return {}, {}, []

    groups = {}
    for repo in sorted(repos_root.iterdir()):
        if repo.is_dir():
            groups.setdefault(repo_key(repo), []).append(repo)

    primary, copies, canonical_names = {}, {}, []
    for repos in groups.values():
        elected = canonical([repo.name for repo in repos])
        canonical_names.append(elected)
        for repo in repos:
            target = primary if repo.name == elected else copies
            for rel in tracked_files(repo):
                target.setdefault(rel.rsplit("/", 1)[-1], []).append((repo.name, rel, repo / rel))
    return primary, copies, sorted(canonical_names)


def resolve(index, cited):
    base = cited.rsplit("/", 1)[-1]
    return [
        entry for entry in index.get(base, ())
        if entry[1] == cited or entry[1].endswith("/" + cited)
    ]


MAX_CANDIDATES = 3


def readable_candidates(matches):
    paths = sorted({f"{repo}/{rel}" for repo, rel, _ in matches})
    shown = ", ".join(paths[:MAX_CANDIDATES])
    extra = len(paths) - MAX_CANDIDATES
    return f"{shown} (+{extra})" if extra > 0 else shown


def line_count(path):
    try:
        with open(path, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def main():
    if len(sys.argv) != 3:
        print("usage: citations.py <epic-dir> <repos-root>", file=sys.stderr)
        return 2
    epic_dir = pathlib.Path(sys.argv[1])
    if not epic_dir.is_dir():
        print(f"citations: not a directory: {epic_dir}", file=sys.stderr)
        return 2

    all_citations = list(citations(epic_dir))
    primary, copies, canonicals = build_index(pathlib.Path(sys.argv[2])) if all_citations else ({}, {}, [])
    counts = {"MISSING": 0, "SHORTENED": 0, "AMBIGUOUS": 0, "BRANCH-ONLY": 0}

    for item in all_citations:
        matches = resolve(primary, item["path"])
        branch_matches = [] if matches else resolve(copies, item["path"])
        if branch_matches:
            status = "BRANCH-ONLY"
            detail = ", ".join(sorted({repo for repo, _, _ in branch_matches}))
        elif not matches:
            status, detail = "MISSING", ""
        elif len(matches) > 1:
            status = "AMBIGUOUS"
            detail = readable_candidates(matches)
        else:
            repo, rel, abspath = matches[0]
            total = line_count(abspath)
            if item["end"] > total:
                status, detail = "SHORTENED", f"{repo}/{rel} has {total} lines"
            else:
                continue
        counts[status] += 1
        line = f"{status:<{STATUS_WIDTH}} {item['origin']}   {item['citation']}"
        print(f"{line}   {detail}" if detail else line)

    parts = [f"SUMMARY {len(all_citations)} citations"]
    labels = (
        ("missing", "MISSING"), ("shortened", "SHORTENED"),
        ("ambiguous", "AMBIGUOUS"), ("branch only", "BRANCH-ONLY"),
    )
    for label, key in labels:
        if counts[key]:
            parts.append(f"{counts[key]} {label}")
    if any(counts.values()):
        print()
    print(" · ".join(parts))
    if canonicals:
        print(f"REFERENCE {len(canonicals)} canonical repos in current checkout state")
    return 0


if __name__ == "__main__":
    sys.exit(main())
