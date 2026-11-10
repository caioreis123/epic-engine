#!/usr/bin/env python3
"""Captures git reference snapshots for remote tracking branches."""
import json
import pathlib
import subprocess
import sys

TIMEOUT_SECONDS = 30
REMOTE = "origin"
HEAD_PREFIX = "refs/heads/"


def git(repo, *arguments):
    return subprocess.run(
        ["git", "-C", str(repo), *arguments], check=True,
        capture_output=True, text=True, timeout=TIMEOUT_SECONDS,
    ).stdout.strip()


def snapshot(repo, branch=None):
    git(repo, "fetch", "--quiet", REMOTE)
    references = ["HEAD", HEAD_PREFIX + branch] if branch else ["HEAD"]
    advertised = git(repo, "ls-remote", "--symref", REMOTE, *references)
    default_branch = next(
        line.split()[1].removeprefix(HEAD_PREFIX)
        for line in advertised.splitlines() if line.startswith("ref: " + HEAD_PREFIX)
    )
    base_ref = "%s/%s" % (REMOTE, default_branch)
    target_ref = "%s/%s" % (REMOTE, branch) if branch else base_ref
    base_sha = git(repo, "rev-parse", "--verify", base_ref)
    target_name = HEAD_PREFIX + branch if branch else "HEAD"
    target_sha = next((line.split()[0] for line in advertised.splitlines()
                       if not line.startswith("ref: ") and line.split()[-1] == target_name), None)
    if target_sha and git(repo, "rev-parse", "--verify", target_ref) != target_sha:
        raise ValueError("remote changed during snapshot; fetch again")
    return {
        "base_ref": base_ref,
        "base_sha": base_sha,
        "ref": target_ref,
        "sha": target_sha,
    }


if __name__ == "__main__":
    try:
        print(json.dumps(snapshot(pathlib.Path(sys.argv[1]), *sys.argv[2:])))
    except (IndexError, StopIteration, ValueError, subprocess.SubprocessError) as error:
        print("repo-ref: %s" % error, file=sys.stderr)
        sys.exit(1)
