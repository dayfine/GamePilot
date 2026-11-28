# Bank in HOME

Moves Pokémon Legends: Z-A's claimed gifts into Pokémon HOME: from the Switch's HOME menu it opens
Pokémon HOME on Legends: Z-A, moves each gift from the game's Box 1 to the first empty slot of its
HOME boxes, saves HOME and closes it. Run it after AutoStory and Claim Gifts.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- The gifts are in the game's Box 1, first row, in the slots of the gift catalog
  ([Claim Gifts](../plza/claim-gifts.md#the-gifts)), where Claim Gifts leaves them.
- Legends: Z-A and Pokémon HOME are installed, and their tiles are among the first 8 on the
  Switch's HOME menu. The console may be anywhere the HOME button reaches the HOME menu; a running
  game is closed.
- The HOME boxes the gifts go to, the catalog's, have an empty slot.
- The Switch's capture is the whole 1920x1080 picture (the daemon's `--viewport native`).

<!-- needs: PLZA's plans state no needs -->

## Running it

The gifts, their slots and their HOME boxes are the gift catalog's
(`src/games/pokemon/plza/gift_catalog/gifts.json`), the one place they are written. A gift whose
last day is before today (the host's date, in UTC) is skipped, with a line in the log, as Claim
Gifts skips it: its slot is empty on a save claimed after that day.

<!-- generated:options -->
This program takes no options.
<!-- /generated -->

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run pokemon_home.bank-plza --from 01-bank-gifts --to 01-bank-gifts --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

To look at HOME's boxes before a run, `gamepilot ctl home-boxes plza` opens Pokémon HOME on the game and logs
the box number and HOME's box, moving nothing (close HOME by hand afterwards, without saving).

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-bank-gifts | The gifts from the game's box into their HOME boxes, saved |

<!-- plans: 94e184961282 -->
<!-- /generated -->

## When it stops

<!-- preflight: PLZA's plans state no pre-flight -->

- Legends: Z-A's tile is not among HOME's first 8 tiles: `home_tile_not_found`, before anything
  opens.
- A catalog gift's slot past Box 1's first row, or every Pokémon gift expired: refused before
  the console moves (the catalog itself refuses a HOME box that is not 1 to 300).
- A move fails its check (the game's slot empty, the cursor off its slot, every HOME box full, a
  box number unread): `home_bank_failed`. Pokémon HOME stays open and unsaved; closing it from
  the HOME menu discards the moves made.
- The run folder keeps the story log, the wire log and `failure.png`, the last frame of a failed
  run.

## Known limits

- Every Pokémon of the catalog that has not expired is moved: one Claim Gifts failed leaves its
  slot empty, and the bank stops there (`home_bank_failed`), so a missing Pokémon is never left
  out unseen.
- A gift claimed on or before its last day but banked after it stays in the game's box.
- A run is one attempt with no retry: a failed bank leaves HOME open for a look.

## How it works

`Plza_checkpoint_series.Checkpoint_series` runs each checkpoint in its own daemon and run folder,
with the watch page, as it runs AutoStory's; `Plza_bank_home_series.Bank_home_runs` gives it
bank-home's attempt. `Plza_bank_home.Bank_home_game` checks the start (it
walks HOME's tile row to Legends: Z-A's title, `Switch.Home_title`) and gives the engine one
game action, `bank_in_home`.

Its moves come from the gift catalog (`Plza_gift_catalog`), turned into `Pokemon_home.Box_moves`
by `Plza_bank_home.Catalog_moves`, which leaves out the gifts `Gift_catalog.expired` says have
expired (Claim Gifts' rule); `src/bin/plza_gift_inputs.ml` reads the catalog and today's date
before the run.

The action is `Pokemon_home.Home_bank`: HOME opened on the game (`Home_launch`), each move (`Box_moves`), then the save, whose saving banner and
then main menu or saved banner are the checkpoint's end check, and HOME closed.
