# Programs

Every program GamePilot runs is listed in the program registry, `src/program_registry/lib/`, as
PA/CC lists its programs (game, then group, then program). `gamepilot programs` prints the list.

A descriptor (`Program_registry.t`) gives:

- `id`: `<game>.<program>`, e.g. `frlg.mail_glitch`; the program's folder is
  `src/games/<game>/programs/<program>/`.
- the game (`Program_registry.game`): its id and display name, its Switch titles' icons on their
  Delete Save Data page by the key `gamepilot ctl delete-save` takes (`delete_save_icons`), and its
  Switch HOME data when measured (`switch_home`: the title park and resume go back to, its HOME
  tile's colour, the lab app panel whose console setup `gamepilot switch-devices` reads, and the
  template of its title on HOME a launch walks the tile row to, if cut). The lab console's game is
  `$GAMEPILOT_LAB_GAME`, else the one game with Switch HOME data. A game may have no program yet. Then the display name, the group path
  (`["FRLG"; "Glitches"]`) and a one-line description;
- `doc`: its page, from the repo root (a page in this folder, or an existing one);
- `checkpoints`: its plans folder, or none for a one-shot program (`gamepilot run`);
- the backends it runs on;
- `viewport`: where its game picture sits in a Switch capture, `Nso_gba` (a GBA game in the
  Switch's GBA app: every FRLG program) or `Native` (a full-screen Switch game, the whole frame).
  Every daemon of its Switch runs takes it as `--viewport nso-gba|native` (`daemon/src/viewport.h`):
  the checkpoints' daemons, the pre-flight's, 00-make-room's and the bring-up's frame check
  (`gamepilot bring-up --program ID`), so no run needs the flag and a native game never runs with
  the GBA picture. An explicit `--viewport` that differs from the program's is refused; it is
  only for a plan folder no program registers.
- `rules`: the rules its checkpoint plans are written over, which pick the library that loads and
  runs them (`Pokemon_grid`: the Pokémon grid rules, FRLG's runner). `src/bin/checkpoint_families.ml`
  is the one place in `src/bin` that picks a family's code from it.

To add a program, add its descriptor to the list in `program_registry.ml` (registration is that
list; nothing registers itself at start-up) and write its page, and its player's guide in
`docs/guide/` (`gamepilot guide --write` starts it; `docs/guide/README.md`). The registry's tests check that ids
are unique, that every doc and checkpoints folder exists, and that every plan decodes. A one-shot
program also needs its runner in its family's `one_shots` (`src/bin/checkpoint_families.ml`).

What a program needs of the save (free party slots, field moves) is not declared: it is derived
from its plans, the same way the pre-flight derives it.

Each run's `run.json` carries the program's game, id, display name and group, so the hub's runs
list can show and filter them (`docs/design/Watch-Page.md`). `gamepilot runs --backfill` adds a
`run.json` to run folders from before it, from the checkpoint id in the folder's name (dry run;
`--apply` writes).
