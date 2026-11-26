# Claim Gifts

Claims Pokémon Legends: Z-A's Mystery Gifts on the Switch: every gift of its catalog that has not
expired, by code or from the Internet list. It puts each gift's Pokémon in its Box 1 slot, checks it there, saves,
and reports on each gift. Run it after AutoStory, whose last checkpoint (Mable's reward) unlocks
Mystery Gift.

<!-- generated:backends -->
Runs on: the Switch.
<!-- /generated -->

## Before you start

- A save past AutoStory's last checkpoint (`03.15-mable-reward`, Mable's reward), where Mystery Gift
  opens.
- The console on the overworld or the main menu, online for Internet gifts.
- Five Pokémon of your own in the party, all at full HP. Party slot 6 is empty, or holds a gift an
  earlier run left there: a sixth Pokémon is taken for a gift and moved to Box 1.
- Box 1 empty in the gifts' slots (the table below), or holding those gifts already.
- Box 1 keeps its own name ("Box 1", "ボックス1"): the run finds it by its title.
- 20 boxes or fewer: a "Box 21" or "Box 31" title would read as Box 1.
- The Switch's capture the whole 1920x1080 picture (`--viewport native`, from the registry).

## Running it

<!-- generated:commands -->
```sh
# the Switch: each checkpoint once, from where the console is
cd src && opam exec -- dune exec -- gamepilot run plza.claim-gifts --from 01-claim-gifts --to 01-claim-gifts --mode testing --backend switch --serial PORT --capture DEVICE \
    --watch
```
<!-- /generated -->

<!-- generated:options -->
Give each as `--options KEY=VALUE`:

| Key | Values | When not given | What it chooses |
|---|---|---|---|
| `language` | en \| es-ES \| es-419 \| fr \| de \| it \| ja \| ko \| zh-Hans \| zh-Hant | default `en` | the game's language, by its language list's tag, in which the Internet gifts' names are found in their list |
<!-- /generated -->

## The gifts

<!-- generated:gifts -->
| Gift | How | Code | Last day | Lands in | HOME boxes |
|---|---|---|---|---|---|
| Vivillon (Poké Ball Pattern) | internet |  | 2027-02-25 | Box 1 slot 2 | 166, 167 |
| Shiny Xerneas (30th anniversary) | code | `CELEBRATE30TH` | 2027-01-07 | Box 1 slot 1 | 165, 164 |
| 5 Max Revives, 10 Full Restores, 10 Ultra Balls | code | `PREPAR1NG` | 2027-03-31 | none (items) |  |
<!-- /generated -->

A gift whose last day is before today (the host's date, in UTC) is skipped, with a line in the log.
The catalog is `src/games/pokemon/plza/gift_catalog/gifts.json`; each gift names the page
that announced it.

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| 01-claim-gifts | Claim the catalog's Mystery Gifts, box them and save |

<!-- plans: 227a3d8005cc -->
<!-- /generated -->

The run prints today's date and the catalog, opens the main menu and reads the party. Then the
Boxes, which open on the box you last looked at: the run presses L, a box at a time, until the box
title reads "Box 1" (its last glyph a narrow "1"), and reads each due gift's slot there.

When party slot 6 holds a Pokémon (a gift an earlier run left there), it is carried to the first
gift slot read empty and read there. Leaving the Boxes on Box 1 makes it the box a gift lands in when
the party is full.

Each gift is then claimed from the main menu and back: Link Play, Mystery Gift, then the code typed
on the keyboard, or the gift found by its name in the Internet list. Its card means it was received.
The game's message that the gift was received, or its code used, before means it is already
received: no claim, and nothing to check.

Then the Boxes again, on Box 1: the gift received into party slot 6 is carried to its slot, and each
Pokémon gift received in this run must read in its slot. Save Progress saves when a gift was
received or a Pokémon moved: it waits on the SAVE dialog until the current time reaches the next
minute (up to a minute), saves, and checks that "Last Saved" changed. The last line of the log is one line
a gift: claimed, already received, expired, not supported or failed.

A gift is known by where the game puts it, not by its species: received into a party of five it
lands in party slot 6, the first one received.

## When it stops

- No main menu after X: `not_on_main_menu`.
- Not five or six Pokémon at full HP on the menu's cards: `party_not_ready`.
- A gift not received (not listed, no card after the claim) fails that gift; the run goes on with
  the next one. After every gift the way back to the main menu reads each screen before a press:
  Yes to "stop receiving?" and "disconnect?", A past a message, B anywhere else; never A on the
  gift list, where it would claim another gift. A screen no reader knows after a claim is kept as
  `gift-<id>-unknown-screen.png` in the run folder.
- No main menu after 12 presses on the way back: `screen_lost`; the gifts after it are not tried.
- A gift received in this run not in its Box 1 slot after the move, its slot not read, or its slot
  already holding a Pokémon before the claims: `gifts_not_in_place`, naming each such gift, before
  the save.
- A Pokémon carried from party slot 6 whose target does not read empty is put back, its cell read
  empty first; when that does not read empty either, the run stops with the Pokémon in hand and
  the Boxes open (`boxes_not_read`).
- The Boxes, a box title or the menu after them not read, or no title read as Box 1 after 32 L:
  `boxes_not_read`, before any Pokémon is moved; "Last Saved" unchanged: `not_saved`.
- Any gift failed: `gifts_failed`, naming each, after the save.
- A failed run is not retried with a reload, which would lose gifts not yet saved.

## Known limits

- The "received before" and "code used before" messages are read in Japanese only (console B's
  captures). In another language a gift claimed twice fails as an unknown screen, with its frame
  kept, and a used code stops at its message.
- HOME gifts are not claimed. An Internet gift needs its name's template in the game's language;
  only the Poké Ball Pattern Vivillon has one, in English, French, Japanese and Simplified Chinese.
- Gifts are told apart by where they land, not by species. Gifts received into a full party land in
  Box 1's first free slots in the order received, which may not be the catalog's slots: the check
  then fails them.
- Box 1 found by its title, and the move from party slot 6, have not yet been run on a console.

## How it works

`Plza_claim_gifts.Claim_gifts` decides: which gifts are due, what came of each, where each Pokémon
must be. `Plza_claim_gifts_series.Claim_gifts_runs` runs its plan on PLZA's shared series loop
(`Plza_checkpoint_series`), one attempt with no reload. `src/bin/plza_gift_inputs.ml` reads the run's
inputs at the edge: the catalog (`Plza_gift_catalog`), today's date and the name templates.

`Gift_claim` claims one gift (`Mystery_gift`'s presses and waits). `Save_progress` saves.

`Gift_boxes` opens the Boxes on Box 1, moves party slot 6's Pokémon and reads the gifts' slots, with
`Box_paging` (L to Box 1) and `Box_cursor` (the cursor's moves and carries). The readers are PLZA's
`Mystery_gift_screen`, `Received_before`, `Main_menu_row`, `Boxes_screen`, `Box_cell`, `Box_title`
and `Save_dialog`, and the Switch's `Code_keyboard`.
