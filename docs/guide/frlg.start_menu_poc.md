# Start Menu PoC (FireRed, development)

A developer's check, not something a player needs: it opens and closes FireRed's Start menu on mGBA
through the daemon, the first program GamePilot ran. Use it to see that the daemon, mGBA and the
`gamepilot` command talk to each other.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

Any FireRed save state with the player in the overworld and the Start menu closed. By default it
loads the Pallet Town state the program names; `--state PATH` loads another, `--console` loads none.

## Running it

The runner script starts mGBA, the program's own daemon and its watch page, and closes mGBA after:

```sh
sh run/run_checkpoints_on_mgba.sh frlg.start_menu_poc
```

On an mGBA you started yourself with the bridge, `--watch` starts the daemon and the page
(`--mgba-port N`: the port the bridge printed). Without `--watch` it runs on a daemon already up on
`--port` (47900), as `docs/poc-start-menu.md` shows:

<!-- generated:commands -->
```sh
cd src && opam exec -- dune exec -- gamepilot run frlg.start_menu_poc
```
<!-- /generated -->

## What happens

It presses Start, waits for the menu, presses B and waits for the menu to close. It prints
`start_menu_poc: PASS` with the times it took, in well under a second.

## When it stops

A `FAIL` line says which wait timed out. Check that the daemon runs and that mGBA shows the
overworld, then run it again. There is nothing to resume.

## Known limits

mGBA only. It changes nothing in the game.
