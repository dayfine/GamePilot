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

Start mGBA with the bridge and the daemon first, as `docs/poc-start-menu.md` shows, then:

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
