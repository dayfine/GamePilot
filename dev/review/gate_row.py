#!/usr/bin/env python3
"""Reads one PR as `gh pr view N --json number,title,headRefOid,files,reviews,statusCheckRollup`
prints on stdin and prints its gate row: NUMBER CI STRUCT NEXT, tab-separated, then the title.

CI is pass / fail / pending / none, over the checks at the PR's tip. STRUCT is the qc-structural
verdict at the tip: ok (APPROVED), rework (NEEDS_REWORK), stale(<sha>) when the latest verdict was
given at an older commit, none, or skip for a docs-only PR (every file is a .md or under docs/).

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


def next_action(ci, struct):
    if ci == "fail":
        return "fix CI"
    if ci in ("pending", "none"):
        return "wait for CI"
    if struct == "rework":
        return "rework"
    if struct in ("ok", "skip"):
        return "user review"
    return "run qc-structural"


def main():
    pr = json.load(sys.stdin)
    ci, struct = ci_state(pr), struct_state(pr)
    print("\t".join([str(pr["number"]), ci, struct, next_action(ci, struct), pr.get("title", "")]))


if __name__ == "__main__":
    main()
