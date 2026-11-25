# User guides

How to run each GamePilot program, written for a player rather than a developer: what it does,
what your save needs, the commands, what happens, how long it takes and what to do when it stops.
Each page ends with "How it works", for developers: the ported files, the mechanics and the timings.

<!-- generated:programs -->
| Program | Id | Runs on | What it does |
|---|---|---|---|
| [Start Menu PoC](frlg.start_menu_poc.md) | `frlg.start_menu_poc` | mGBA | Opens and closes the Start menu: the first program through the daemon. |
| [Mail Glitch](frlg.mail_glitch.md) | `frlg.mail_glitch` | mGBA, the Switch | Turns on the Mail Glitch against Lea & Jed on Route 16 and copies one item with it. |
| [Supplies](frlg.supplies.md) | `frlg.supplies` | mGBA, the Switch | Stocks what the duplication programs use: Retro Mail and Super Repels. |
| [Team Training](frlg.team_training.md) | `frlg.team_training` | mGBA, the Switch | Copies Rare Candies with the Mail Glitch to level the team. |
| [Sevii Story](frlg.sevii_story.md) | `frlg.sevii_story` | mGBA | Plays the Sevii Islands story after the Cinnabar Gym. |
| [Dex Collection](frlg.dex_collection.md) | `frlg.dex_collection` | mGBA | Catches Pokemon the Pokedex lacks, toward the National Pokedex. |
| [Wild RNG](frlg.wild_rng.md) | `frlg.wild_rng` | mGBA | Catches a chosen shiny wild Pokemon by timing the game's random numbers. |
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

The blocks:

- `programs`: this table.
- `backends`: where it runs (on the Switch, with its game picture).
- `checkpoints [RANGE]`: each checkpoint's title, and a digest of its plans, so any plan change
  needs a regenerated page.
- `needs [RANGE]`: what the save needs for the chain, from the pre-flight.
- `preflight [RANGE]`: what the pre-flight checks before each checkpoint.
- `commands [RANGE]`: the commands that run it.

RANGE is `FROM..TO` or one checkpoint id; without it, every checkpoint. A new page starts from a
skeleton whose `TODO(guide)` the check refuses until the prose is written.

Write for a player who reads in passing:

- Open with what the program does in one or two sentences, then at most a short paragraph. Keep the
  registry's `description` to one short sentence.
- No hand-written paragraph or list item over 5 lines; `guide --check` names the file and line of
  one that is.
- What the save needs and the steps to take go in lists. Leave to the "What happens" table what it
  already says.

## Adding a program

Every program GamePilot runs is listed in the program registry, `src/program_registry/lib/`, as
PA/CC lists its programs (game, then group, then program). `gamepilot programs` prints the list.
A descriptor (`Program_registry.t`) gives:

- `id`: `<game>.<program>`, e.g. `frlg.mail_glitch`; the program's folder is
  `src/games/<game>/programs/<program>/`.
- the game (`Program_registry.game`): its id and display name, its Switch titles' icons on their
  Delete Save Data page by the key `gamepilot ctl delete-save` takes (`delete_save_icons`), and its
  Switch HOME data when measured (`switch_home`: the title park and resume go back to, its HOME
  tile's colour, and the lab app panel whose console setup `gamepilot switch-devices` reads).
- the display name, the group path (`["FRLG"; "Glitches"]`) and a one-line description.
- `doc`: its guide, `docs/guide/<program id>.md` (or an existing page, for a proof of concept).
- `checkpoints`: its plans folder, or none for a one-shot program (`gamepilot run`).
- the backends it runs on.
- `viewport`: where its game picture sits in a Switch capture, `Nso_gba` (a GBA game in the
  Switch's GBA app: every FRLG program) or `Native` (a full-screen Switch game, the whole frame).
- `rules`: the rules its checkpoint plans are written over, which pick the library that loads and
  runs them (`Pokemon_grid`: the Pokémon grid rules, FRLG's runner). `src/bin/checkpoint_families.ml`
  is the one place in `src/bin` that picks a family's code from it.

The lab console's game is `$GAMEPILOT_LAB_GAME`, else the one game with Switch HOME data. A game
may have no program yet (PLZA, for delete-save).

Every daemon of a program's Switch runs takes its viewport as `--viewport nso-gba|native`
(`daemon/src/viewport.h`): the checkpoints' daemons, the pre-flight's, 00-make-room's and the
bring-up's frame check (`gamepilot bring-up --program ID`), so no run needs the flag and a native
game never runs with the GBA picture. An explicit `--viewport` that differs is refused; it is only
for a plan folder no program registers.

To add a program, add its descriptor to the list in `program_registry.ml` (registration is that
list; nothing registers itself at start-up) and write its guide here (`gamepilot guide --write`
starts it). The registry's tests check that ids are unique, that every doc and checkpoints folder
exists, and that every plan decodes. A one-shot program also needs its runner in its family's
`one_shots` (`src/bin/checkpoint_families.ml`).

What a program needs of the save (free party slots, field moves) is not declared: it is derived
from its plans, the same way the pre-flight derives it.

Each run's `run.json` carries the program's game, id, display name and group, so the hub's runs
list can show and filter them (`docs/design/Watch-Page.md`). `gamepilot runs --backfill` adds a
`run.json` to run folders from before it, from the checkpoint id in the folder's name (dry run;
`--apply` writes).
