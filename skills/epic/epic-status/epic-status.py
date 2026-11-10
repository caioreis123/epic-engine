#!/usr/bin/env python3
"""Epic Status Panel: Inspects frontmatter metadata without reading file bodies."""
import os
import pathlib
import re
import sys

LIB_DIR = pathlib.Path(os.environ.get("EPIC_LIB_DIR", pathlib.Path(__file__).resolve().parents[3] / "lib" / "epic-lib"))
sys.path.insert(0, str(LIB_DIR))

import frontmatter  # noqa: E402
import repo_ref     # noqa: E402

DECOMPOSE_THRESHOLD = 30
SETTLED_MARK = "\u2713"
SETTLED_SHOWN = 5
NEEDS_LIVE = "(requires --live)"
JIRA_KEY_RE = re.compile(r"\b([A-Z][A-Z0-9]+-\d+)\b")

JIRA_RANK = {
    "backlog": 0, "to do": 0, "in progress": 1, "code review": 2, "done": 3,
}
JIRA_INACTIVE = {"parking lot", "canceled", "cancelled"}
JIRA_DONE = {"done"}

LANDED_WINDOW = "6 months ago"
LAUNCH_STEP_FIELD = "stage"
LAUNCH_EMAIL_STEP = "email"
MERGE_STEP = "merge"
FINDING_DONE = "completed"

POST_EXPERIMENT_STEP = "validate-post-experiment"
POST_EXPERIMENT_GO = "GO"
POST_EXPERIMENT_NO_GO = "NO-GO"

VALIDATION_DRAFT = "draft"
VALIDATION_FAILED = "failed"
VALIDATION_FAILURES = {VALIDATION_FAILED, "rejected"}
VALIDATION_WAIVED = "waived"
VALIDATION_PASSED = {"passed", "executed", VALIDATION_WAIVED}

VALIDATION_FREE_REPOS = {"visual-check"}
TASK_ID_RE = re.compile(r"\btask-\d+\b")
SHA_RE = re.compile(r"^[a-f0-9]{40}$")
TRACKING_REQUIRED = {"#", "task", "stage", "repo"}
RELEASE_LINE_PREFIX = "| Release announcement"
DELIVERY_LINE_PREFIX = "| Feature delivery announcement"
NOTION_HOSTS = ("app.notion.com", "notion.so")

STATUS_RANK = {
    "draft": 0, "open": 1, "in progress": 2, "review": 3, "completed": 4,
}

REPO_ALIAS = {
    "graphql-bff": "bff",
    "web-app": "web",
    "visual-check": "vc",
}


def _run(args, timeout=15):
    import subprocess
    try:
        proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return proc.stdout.strip()
    except Exception:
        return ""


def _pluralize(n, singular, plural):
    return f"{n} {singular}" if n == 1 else f"{n} {plural}"


def _short_timestamp(stamp):
    if not stamp:
        return ""
    return stamp.replace("T", " ")[:16]


def _finding_line(path):
    fields = frontmatter.read(path)
    label = path.stem
    conclusions = fields.get("conclusions") or []
    if not conclusions:
        return "?  %s -> %s" % (label, "incomplete frontmatter")

    last = frontmatter.last_conclusion(conclusions)
    val = (last.get("value") or "").strip().lower()
    stamp = _short_timestamp(last.get("at"))

    if val in ("confirmed", "confirmado"):
        mark = SETTLED_MARK
    elif val in ("refuted", "refutado"):
        mark = "\u2717"
    else:
        mark = "?"

    short = fields.get("short_answer") or fields.get("resposta_curta") or ""
    line = f"{mark}  {label:<30} {val:<12} {stamp}"
    if short:
        line += f"  {short}"
    return line


def _decision_line(path):
    fields = frontmatter.read(path)
    label = path.stem
    title = fields.get("title") or fields.get("titulo") or ""
    return f"{SETTLED_MARK}  {label:<30} {title}"


def _tracking_rows(plans):
    rows = []
    for plan in plans:
        text = plan.read_text(encoding="utf-8")
        in_table = False
        headers = []
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("|") and not in_table:
                cols = [c.strip().lower() for c in line.split("|")[1:-1]]
                if TRACKING_REQUIRED.issubset(set(cols)):
                    in_table = True
                    headers = cols
                    continue
            if in_table and line.startswith("|"):
                if re.match(r"^\|[-:| ]+\|$", line):
                    continue
                cells = [c.strip() for c in line.split("|")[1:-1]]
                if len(cells) == len(headers):
                    data = dict(zip(headers, cells))
                    m_card = JIRA_KEY_RE.search(data.get("card", "") or data.get("jira", ""))
                    rows.append({
                        "n": data.get("#", ""),
                        "task": data.get("task", ""),
                        "stage": data.get("stage", "implement"),
                        "repo": data.get("repo", ""),
                        "jira": m_card.group(1) if m_card else "",
                        "id": f"task-{data.get('#', '')}",
                    })
            elif in_table and not line.startswith("|"):
                break
    return rows


def _validation_statuses(epic_dir):
    directory = epic_dir / "validations"
    if not directory.is_dir():
        return []
    return [frontmatter.read(path).get("status", "")
            for path in sorted(directory.glob("*.md"))]


def _step_finding_done(epic_dir, step):
    for fields in map(frontmatter.read, (epic_dir / "findings").glob("*.md")):
        if fields.get(LAUNCH_STEP_FIELD) == step and fields.get("status") == FINDING_DONE:
            return True
        if fields.get("stage") == step and fields.get("status") == "completed":
            return True
    return False


def _post_experiment_verdict(epic_dir):
    verdicts = [fields.get("verdict") or fields.get("veredito")
                for fields in map(frontmatter.read, sorted((epic_dir / "findings").glob("*.md")))
                if (fields.get(LAUNCH_STEP_FIELD) == POST_EXPERIMENT_STEP or fields.get("stage") == POST_EXPERIMENT_STEP)
                and (fields.get("status") == FINDING_DONE or fields.get("status") == "completed")]
    return verdicts[-1] if verdicts else None


def _post_experiment_step(epic_dir, slug):
    verdict = _post_experiment_verdict(epic_dir)
    if verdict == POST_EXPERIMENT_GO:
        return None
    if verdict == POST_EXPERIMENT_NO_GO:
        return (None, "post-experiment validation rejected: resolve configuration and re-run "
                      "/epic-validate-post-experiment %s" % slug)
    if verdict is None:
        return ("/epic-validate-post-experiment %s" % slug,
                "post-merge validation completed; experiment activation needs validation")
    return ("/epic-validate-post-experiment %s" % slug,
            "post-experiment validation pending GO verdict")


def _prs_merged(epic_dir):
    return _step_finding_done(epic_dir, MERGE_STEP) or (epic_dir / "validations" / "post-merge").is_dir()


def _has_xplan(epic_dir):
    links = epic_dir / "links.md"
    if not links.is_file():
        return False
    return "x-plan" in links.read_text(encoding="utf-8").lower()


def _tail_step(epic_dir, slug, rows=()):
    statuses = _validation_statuses(epic_dir)
    if not statuses and any(row["repo"] not in VALIDATION_FREE_REPOS for row in rows):
        return ("/epic-validate-pre-merge %s" % slug,
                "delivery completed; requires pre-merge injection point validation")
    if VALIDATION_DRAFT in statuses:
        return (None, "validation plan written in draft: execute and record result")
    if any(value in VALIDATION_FAILURES for value in statuses):
        return (None, "pre-merge validation failed: inspect verdict before merging")
    if not _prs_merged(epic_dir):
        return ("/epic-merge %s" % slug,
                "pre-merge validation passed; integration PRs ready to merge")
    if _has_xplan(epic_dir) and not (epic_dir / "validations" / "post-merge").is_dir():
        return ("/epic-validate-post-merge %s" % slug,
                "merged to main; production journey validation (state x surface) pending")
    if _has_xplan(epic_dir):
        post_exp = _post_experiment_step(epic_dir, slug)
        if post_exp:
            return post_exp
    return ("/epic-release-experiment %s" % slug,
            "all validation gates passed; ready to announce experiment")


def render(epic_dir, live=False):
    findings = sorted((epic_dir / "findings").glob("*.md"))
    decisions = sorted((epic_dir / "decisions").glob("*.md"))
    specs = sorted((epic_dir / "specs").glob("*.md")) if (epic_dir / "specs").is_dir() else []
    plans = [path for path in sorted((epic_dir / "plans").glob("*.md"))
             if not path.stem.endswith(("-summary", "-split"))]

    lines = []
    header = "%s        %s - %s" % (
        epic_dir.name,
        _pluralize(len(findings), "finding", "findings"),
        _pluralize(len(decisions), "decision", "decisions"),
    )
    if not specs:
        header += " - no spec"
    lines.append(header)

    lines.append("")
    lines.append("FINDINGS")
    rendered = [_finding_line(path) for path in findings]
    settled = [line for line in rendered if line.startswith(SETTLED_MARK)]
    open_items = [line for line in rendered if not line.startswith(SETTLED_MARK)]

    if len(settled) > SETTLED_SHOWN:
        for line in settled[:SETTLED_SHOWN]:
            lines.append("  " + line)
        lines.append("  ... and %d more settled findings" % (len(settled) - SETTLED_SHOWN))
    else:
        for line in settled:
            lines.append("  " + line)

    for line in open_items:
        lines.append("  " + line)

    lines.append("")
    lines.append("DECISIONS")
    for path in decisions:
        lines.append("  " + _decision_line(path))

    rows = _tracking_rows(plans)
    slug = epic_dir.name
    next_step, reason = _tail_step(epic_dir, slug, rows)

    lines.append("")
    lines.append("NEXT")
    if next_step:
        lines.append(f"  {next_step}  ({reason})")
    else:
        lines.append(f"  (waiting: {reason})")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("usage: epic-status.py <epic-dir>", file=sys.stderr)
        return 2
    epic_dir = pathlib.Path(sys.argv[1])
    if not epic_dir.is_dir():
        print(f"epic-status: not a directory: {epic_dir}", file=sys.stderr)
        return 2
    print(render(epic_dir, live="--live" in sys.argv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
