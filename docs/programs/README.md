# Programs

Every program GamePilot runs is listed in the program registry, `src/program_registry/lib/`, as
PA/CC lists its programs (game, then group, then program). `gamepilot programs` prints the list.

A descriptor (`Program_registry.t`) gives:

- `id`: `<game>.<program>`, e.g. `frlg.mail_glitch`; the program's folder is
  `src/games/<game>/programs/<program>/`.
- the game (id and display name), the display name, the group path (`["FRLG"; "Glitches"]`) and a
  one-line description;
- `doc`: its page, from the repo root (a page in this folder, or an existing one);
- `checkpoints`: its plans folder, or none for a one-shot program (`gamepilot run`);
- the backends it runs on.

To add a program, add its descriptor to the list in `program_registry.ml` (registration is that
list; nothing registers itself at start-up) and write its page. The registry's tests check that ids
are unique, that every doc and checkpoints folder exists, and that every plan decodes. A one-shot
program also needs its case in `gamepilot run` (`src/bin/gamepilot.ml`).

What a program needs of the save (free party slots, field moves) is not declared: it is derived
from its plans, the same way the pre-flight derives it.

Each run's `run.json` carries the program's game, id, display name and group, so the hub's runs
list can show and filter them (`docs/design/Watch-Page.md`). `gamepilot runs --backfill` adds a
`run.json` to run folders from before it, from the checkpoint id in the folder's name (dry run;
`--apply` writes).
