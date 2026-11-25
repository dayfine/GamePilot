# User guides

How to run each GamePilot program, written for a player rather than a developer: what it does,
what your save needs, the commands, what happens, how long it takes and what to do when it stops.
Developer pages are in `docs/programs/`.

<!-- generated:programs -->
| Program | Id | Runs on | What it does |
|---|---|---|---|
| [Start Menu PoC](frlg.start_menu_poc.md) | `frlg.start_menu_poc` | mGBA | Opens and closes the Start menu: the first program through the daemon. |
| [Mail Glitch](frlg.mail_glitch.md) | `frlg.mail_glitch` | mGBA, the Switch | Sets up the Mail Glitch, performs it against Lea & Jed on Route 16 and uses it to duplicate an item. |
| [Supplies](frlg.supplies.md) | `frlg.supplies` | mGBA, the Switch | Stocks what the duplication programs use: Retro Mail and Super Repels. |
| [Team Training](frlg.team_training.md) | `frlg.team_training` | mGBA, the Switch | Farms Rare Candies with the Mail Glitch's item duplication and levels the team with them. |
| [Sevii Story](frlg.sevii_story.md) | `frlg.sevii_story` | mGBA | Plays the Sevii Islands story after the Hall of Fame, starting with Bill's trip to One Island. |
<!-- /generated -->

The Mail Glitch has a second page for its last checkpoint:
[item duplication](frlg.mail_glitch.item_duplication.md).

## For contributors

Each registered program has a page here, `<program id>.md`, and may have more for a part of it,
`<program id>.<part>.md`. The blocks between `<!-- generated:NAME -->` and `<!-- /generated -->`
come from the registry and the plans; everything else is hand-written and kept as it is.

    cd src && opam exec -- dune exec -- gamepilot guide --write    # refill every block; start missing pages
    cd src && opam exec -- dune exec -- gamepilot guide --check    # what CI runs
    cd src && opam exec -- dune exec -- gamepilot guide frlg.mail_glitch    # print a program's blocks

The blocks: `programs` (this table), `backends` (on the Switch, with its game picture), `checkpoints [RANGE]` (each checkpoint's title, and
a digest of its plans, so any plan change needs a regenerated page), `needs [RANGE]` (what the save
needs for the chain, from the pre-flight), `preflight [RANGE]` (what the pre-flight checks before
each checkpoint) and `commands [RANGE]`. RANGE is `FROM..TO` or one checkpoint id; without it, every
checkpoint. A new page starts from a skeleton whose `TODO(guide)` the check refuses until the prose
is written.
