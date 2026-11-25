# Rule audit

The user spot checks PRs, so code written before a rule was stated can still break it. The rule
audit finds those instances across the tree in one pass and turns them into scheduled fixes.

- The rules: `.agents/rules/review-rules.md`, one entry per rule the user has stated in a review,
  each with how to find it (a lint, a recipe, or what to read).
- The auditor: `.agents/agents/rule-audit.md`. It runs every rule's recipe at `origin/main`,
  confirms each hit by reading it, and files one issue, `Rule audit <date>`, labelled `rule-audit`:
  a section per rule with a checkbox per finding (`path:line` and the fix), and the clean rules on
  one line. It never edits code.

## Running it

Dispatch the `rule-audit` agent with an empty brief (every rule) or a list of rule ids (`R3 R5`,
for a rule just added). It needs `gh` with issue rights on `dayfine/GamePilot`, `python3` and the
OCaml toolchain for the lint and `guide --check`.

Run it:

- once a month, as the first step of periodic maintenance;
- after a rule is added to the catalog, for that rule alone, so its older instances are found
  while the review that prompted it is fresh.

Not while an earlier audit issue still has more than about ten unchecked items: finish those
first, or the issues pile up.

## Scheduling the follow-ups

Periodic maintenance takes the latest open `rule-audit` issue
(`gh issue list --repo dayfine/GamePilot --label rule-audit --state open`) and works it in rule
order:

1. Pick the first rule with unchecked items. Its items become **one fix PR** (`Rule R<n>: <what>`,
   body linking the issue and the rule). One concern per PR still holds: a rule whose fixes cross
   a structural line (a plan format change for R4, say) splits into that change first and the
   fixes on top.
2. Items marked "(question)" go to the user first; the PR leaves them out.
3. The PR goes through the PR gate loop like any other. When it merges, tick its items on the
   issue and link the PR beside them.
4. Up to three fix PRs from one audit are open at a time; the next rule waits for a slot.
5. When every item is ticked or answered, close the issue. A rule the audit cannot check well
   (a broken or noisy recipe, listed under "Recipes to fix") gets its recipe fixed in the catalog
   in the same kind of PR.

A finding that a lint could catch every time is worth more than its fix: when one rule keeps
producing findings, its fix PR (or the next) turns the recipe into a check in `dev/lint/` and
the catalog entry names the check.
