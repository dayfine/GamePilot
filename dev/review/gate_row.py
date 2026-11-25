#!/usr/bin/env python3
"""Reads one PR as `gh pr view N --json number,title,headRefOid,reviews,statusCheckRollup,mergeable`
prints on stdin and prints its gate row: NUMBER CI STRUCT NEXT, tab-separated, then the title. An
optional argument names a file of the PR's changed files, one REST `{path, status}` object per line
(pr_gate_status.sh pages them, since `--json files` stops at 100); it replaces any `files` on stdin.

CI is pass / fail / pending / none, over the checks at the PR's tip. STRUCT is the qc-structural
verdict at the tip: ok (APPROVED), rework (NEEDS_REWORK), stale(<sha>) when the latest verdict was
given at an older commit, none, or skip for a docs-only PR (every file is a .md or under docs/).
NEXT is the one next step: "merge main" first when the PR conflicts with main; once CI is green and
the verdict is ok, "merge", or "merge (structural: <reason>)" when the PR changes structure, or
"user review (<reason>)" for a design doc or a PR reworked twice
(AGENTS.md, "PR gate loop"). Structure, read off the file list: a library module or dune file added,
deleted or renamed under src/; a changed .mli of a library shared across games (src/base, src/core,
src/pokemon); a changed format (protocol/, a *_decode.ml); a design doc (docs/design/); or two
NEEDS_REWORK verdicts. The reason printed is the first that holds, in the order: reworked twice,
structure, design doc.

A qc-structural verdict is a COMMENT review (GitHub refuses self-approval, so the review state
says nothing) whose body has a "## Structural QC" heading, a "Reviewed SHA: <sha>" line and a
"## Verdict" heading followed by APPROVED or NEEDS_REWORK. Text inside ``` fences is ignored, so
a review that quotes another one is not read as that one. Used by dev/review/pr_gate_status.sh."""
import json
import re
import sys

PASSING = {"SUCCESS", "SKIPPED", "NEUTRAL"}
PENDING = {"PENDING", "EXPECTED", "QUEUED", "IN_PROGRESS", "WAITING", "REQUESTED"}
SHORT_SHA = 8


def unfenced(body):
    """The body without its ``` fenced blocks."""
    out, fenced = [], False
    for line in body.replace("\r", "").split("\n"):
        if line.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced:
            out.append(line)
    return "\n".join(out)


def verdict(review):
    """(sha, APPROVED | NEEDS_REWORK) for a qc-structural review, else None."""
    text = unfenced(review.get("body") or "")
    if not re.search(r"(?mi)^#+ *Structural QC\b", text):
        return None
    found = re.findall(r"(?mi)^#+ *Verdict[ :*`]*\n*\s*\**(APPROVED|NEEDS_REWORK)", text)
    if not found:
        return None
    sha = re.search(r"(?i)Reviewed SHA:?[ `*]*([0-9a-f]{7,40})", text)
    sha = sha.group(1) if sha else (review.get("commit") or {}).get("oid", "")
    return sha, found[-1].upper()


SHARED = ("src/base/", "src/core/", "src/pokemon/")
MOVED = {"ADDED", "DELETED", "RENAMED"}


def structural_reason(files):
    """Why the file list changes structure, or None."""
    for f in files:
        path, change = f["path"], f.get("changeType", "MODIFIED")
        name = path.rsplit("/", 1)[-1]
        in_lib = path.startswith("src/") and "/lib/" in path
        if change in MOVED and (name == "dune" and path.startswith("src/")
                                or in_lib and name.endswith((".ml", ".mli"))):
            return "module " + change.lower() + ": " + path
        if path.startswith(SHARED) and in_lib and name.endswith(".mli"):
            return "shared interface: " + path
        if path.startswith("protocol/") or name.endswith("_decode.ml"):
            return "format: " + path
    return None


# What still goes to the user; other structural changes merge on an APPROVED verdict (user,
# 2026-11-24), the main session holding one now and then for the user's spot check.
USER_REASONS = ("design doc", "reworked twice")


def owner_reason(pr):
    """Why the PR needs the user's review, or None."""
    files = pr.get("files") or []
    reworks = [v for v in map(verdict, pr.get("reviews") or []) if v and v[1] == "NEEDS_REWORK"]
    if len(reworks) >= 2:
        return "reworked twice"
    design = [f["path"] for f in files if f["path"].startswith("docs/design/")]
    if design:
        return "design doc: " + design[0]
    return structural_reason(files)


def docs_only(files):
    paths = [f["path"] for f in files]
    return bool(paths) and all(p.endswith(".md") or p.startswith("docs/") for p in paths)


def struct_state(pr):
    if docs_only(pr.get("files") or []):
        return "skip"
    tip = pr["headRefOid"]
    verdicts = [v for v in map(verdict, pr.get("reviews") or []) if v]
    if not verdicts:
        return "none"
    at_tip = [v for sha, v in verdicts if sha and tip.startswith(sha)]
    if not at_tip:
        return "stale(" + verdicts[-1][0][:SHORT_SHA] + ")"
    return "ok" if at_tip[-1] == "APPROVED" else "rework"


def check_state(check):
    """pass / fail / pending for one CheckRun or StatusContext."""
    if check.get("__typename") == "StatusContext":
        state = check.get("state", "")
        return "pass" if state == "SUCCESS" else "pending" if state in PENDING else "fail"
    if check.get("status") != "COMPLETED":
        return "pending"
    return "pass" if check.get("conclusion") in PASSING else "fail"


def ci_state(pr):
    states = {check_state(c) for c in pr.get("statusCheckRollup") or []}
    for state in ("fail", "pending", "pass"):
        if state in states:
            return state
    return "none"


def next_action(ci, struct, owner=None, conflicting=False):
    if conflicting:
        return "merge main"
    if ci == "fail":
        return "fix CI"
    if ci in ("pending", "none"):
        return "wait for CI"
    if struct == "rework":
        return "rework"
    if struct in ("ok", "skip"):
        if not owner:
            return "merge"
        if owner.startswith(USER_REASONS):
            return "user review (" + owner + ")"
        return "merge (structural: " + owner + ")"
    return "run qc-structural"


# REST file statuses, as the changeType names `gh pr view --json files` uses.
REST_CHANGE = {"added": "ADDED", "removed": "DELETED", "renamed": "RENAMED"}


def rest_files(lines):
    """The PR's files from REST lines ({path, status} per line), in the `gh pr view` shape."""
    rows = [json.loads(line) for line in lines if line.strip()]
    return [{"path": r["path"], "changeType": REST_CHANGE.get(r["status"], "MODIFIED")}
            for r in rows]


def main():
    pr = json.load(sys.stdin)
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            pr["files"] = rest_files(f)
    ci, struct = ci_state(pr), struct_state(pr)
    conflicting = pr.get("mergeable") == "CONFLICTING"
    step = next_action(ci, struct, owner_reason(pr), conflicting)
    print("\t".join([str(pr["number"]), ci, struct, step, pr.get("title", "")]))


if __name__ == "__main__":
    main()
