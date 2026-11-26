# Claim Gifts

Claims Pokémon Legends: Z-A's Mystery Gifts on the Switch: every gift of its catalog that has not
expired, by code or from the Internet list. It puts each gift's Pokémon in its Box 1 slot, saves,
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
- None of your own Pokémon in the box the Boxes last showed. With a full party the game puts gifts
  there, and the run moves the Pokémon it finds there to Box 1 when there are as many as gifts
  missing.
- The boxes keep their own names ("Box 1", "Box 2", ...): the run finds Box 1 by its title.
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

<!-- plans: acfb0ba2b66b -->
<!-- /generated -->

The run prints today's date and the catalog, opens the main menu and reads the party. Each gift is
claimed from the main menu and back: Link Play, Mystery Gift, then the code typed on the keyboard,
or the gift found by its name in the Internet list. Its card means it was received.

Then the Boxes, which open on the box you last looked at. The run presses L until the box title
grows a digit (Box 1 to the last box) and R once back, so it is on Box 1 whichever box they opened
on, and reads each gift's slot there.

A gift whose slot is empty is looked for: first in party slot 6, then in the box the Boxes opened
on, whose 30 cells are read. Each is carried to its slot (a box's Pokémon by way of party slot 6),
and every gift's slot is read again at the end. A gift is known by where the game puts it, not by
its species: received into a party of five it lands in party slot 6, into a full party in the
first free cells of the box last shown, in the order received.

So a rerun puts gifts an earlier run left elsewhere in place, and moves nothing when they already
are. Save Progress saves when a gift was received or a Pokémon moved, checked by its "Last Saved"
time. The last line of the log is one line a gift: claimed, already received, expired, not
supported or failed.

## When it stops

- No main menu after X: `not_on_main_menu`.
- Not five or six Pokémon at full HP on the menu's cards: `party_not_ready`.
- A gift not received (not listed, no card after the claim) fails that gift; the run goes on with
  the next one. After every gift the way back to the main menu reads each screen before a press:
  Yes to "stop receiving?" and "disconnect?", A past a message, B anywhere else; never A on the
  gift list, where it would claim another gift. A screen no reader knows after a claim is kept as
  `gift-<id>-unknown-screen.png` in the run folder.
- No main menu after 12 presses on the way back: `screen_lost`; the gifts after it are not tried.
- A received gift's box slot empty after the moves, or not read: that gift fails. A gift whose
  claim failed keeps its own failure, moved or not.
- The box the Boxes opened on holds more or fewer Pokémon than the gifts still missing: nothing is
  taken from it, and those gifts fail.
- The Boxes, a box title or the menu after them not read, or no box title widening after 40 L:
  `boxes_not_read`; "Last Saved" unchanged: `not_saved`.
- Any gift failed: `gifts_failed`, naming each, after the save.
- A failed run is not retried with a reload, which would lose gifts not yet saved.

## Known limits

- A gift already received is not yet recognised: no capture of that screen exists. It fails as an
  unknown screen, with its frame kept.
- HOME gifts are not claimed. An Internet gift needs its name's template in the game's language;
  only the Poké Ball Pattern Vivillon has one, in English, French and Japanese.
- Gifts are told apart by where they land, not by species. Two gifts received into a full party
  while the Boxes were left on Box 1 land in its first free slots in the order received, which may
  not be the catalog's slots.
- That L goes round from Box 1 to the last box, and that L, R and moving a box's Pokémon to the
  party work as the run expects, has not yet been run on a console.

## How it works

`Plza_claim_gifts.Claim_gifts` decides: which gifts are due, what came of each, where each Pokémon
must be. `Plza_claim_gifts_series.Claim_gifts_runs` runs its plan on PLZA's shared series loop
(`Plza_checkpoint_series`), one attempt with no reload. `src/bin/plza_gift_inputs.ml` reads the run's
inputs at the edge: the catalog (`Plza_gift_catalog`), today's date and the name templates.

`Gift_claim` claims one gift (`Mystery_gift`'s presses and waits), with a hook,
`Gift_claim.already_received`, where the "already received" reader will go. `Save_progress` saves.

`Gift_boxes` puts the gifts in their slots and reads them, with `Box_paging` (to Box 1 and back),
`Box_cursor` (the cursor's moves and carries) and `Gift_moves` (where each missing gift is looked
for). The readers are PLZA's `Mystery_gift_screen`, `Main_menu_row`, `Boxes_screen`, `Box_cell`,
`Box_title` and `Save_dialog`, and the Switch's `Code_keyboard`.
