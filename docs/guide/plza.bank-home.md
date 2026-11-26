# Bank in HOME

Moves Pokémon Legends: Z-A's claimed gifts into Pokémon HOME: from the Switch's HOME menu it opens
Pokémon HOME on Legends: Z-A, moves each gift from the game's Box 1 to the first empty slot of its
HOME boxes, saves HOME and closes it. Run it after AutoStory and Claim Gifts.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- The gifts are in the game's Box 1, first row: the Xerneas in slot 1, the Vivillon in slot 2, as
  the plan's moves say.
- Legends: Z-A and Pokémon HOME are installed, and their tiles are among the first 8 on the
  Switch's HOME menu. The console may be anywhere the HOME button reaches the HOME menu; a running
  game is closed.
- The HOME boxes the gifts go to have an empty slot: 166 or 167 for the Vivillon, 165 or 164 for
  the Xerneas, unless the options choose others.
- The Switch's capture is the whole 1920x1080 picture (the daemon's `--viewport native`).

<!-- needs: PLZA's plans state no needs -->

## Running it

Each gift's HOME boxes can be chosen for the run; by default they are the plan's.

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `vivillon-boxes` | text | optional | the HOME boxes the Vivillon goes to, tried in order, comma-separated (150,151); by default the plan's |
| `xerneas-boxes` | text | optional | the HOME boxes the Xerneas goes to, tried in order, comma-separated (150,151); by default the plan's |
<!-- /generated -->

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run plza.bank-home --from 01-bank-gifts --to 01-bank-gifts --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

Add the options to the command, for example `--options vivillon-boxes=150,151`. To look at
HOME's boxes before a run, `gamepilot ctl home-boxes plza` opens Pokémon HOME on the game and logs
the box number and HOME's box, moving nothing (close HOME by hand afterwards, without saving).

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-bank-gifts | The gifts from the game's box into their HOME boxes, saved |

<!-- plans: 15d3e15f4cb8 -->
<!-- /generated -->

## When it stops

<!-- preflight: PLZA's plans state no pre-flight -->

- Legends: Z-A's tile is not among HOME's first 8 tiles: `home_tile_not_found`, before anything
  opens.
- An option names a gift the plan does not move, or a box that is not 1 to 300: refused before the
  console moves.
- A move fails its check (the game's slot empty, the cursor off its slot, every HOME box full, a
  box number unread): `home_bank_failed`. Pokémon HOME stays open and unsaved; closing it from
  the HOME menu discards the moves made.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- The gifts' slots in the game's box are fixed by the plan. A later step can take the moves from
  Claim Gifts' gift catalog, whose entries carry each gift's box slot and HOME box.
- A run is one attempt with no retry: a failed bank leaves HOME open for a look.

## How it works

`Plza_bank_home_series.Bank_home_runs` runs each checkpoint in its own daemon and run folder, with
the watch page, as PLZA's story series does. `Plza_bank_home.Bank_home_game` checks the start (it
walks HOME's tile row to Legends: Z-A's title, `Switch_home.Home_title`) and gives the engine one
game action, `bank_in_home`. Its args are read by `Plza_bank_home.Bank_moves_args`, with each
`<gift>-boxes` option over the plan's `home_boxes`.

The action is `Pokemon_home.Home_bank`: HOME
opened on the game (`Home_launch`), each move (`Box_moves`), then the save, whose saving banner and
then main menu or saved banner are the checkpoint's end check, and HOME closed.
