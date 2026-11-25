# Mail Glitch: item duplication (FireRed)

Checkpoint mg-06 of the Mail Glitch program. With the glitch active (the end of mg-05, see
[Mail Glitch: activation](frlg.mail_glitch.md)), it first proves the glitch is there by reading the
glitched mail, then copies one item: one Antidote today.

**What you get.** One more Antidote in the bag, and a party set up for more copies: MIMIEN in slot 1,
the other five each holding a Retro Mail. Each copy costs one Retro Mail ($50 at the Celadon
Department Store).

**Coming next** (not on `main` yet): Supplies (`frlg.supplies`) and Team Training
(`frlg.team_training`) run the same loop many times to duplicate Rare Candies.

<!-- generated:backends -->
Runs on: mGBA, the Switch.
<!-- /generated -->

## How it works, in short

The battle in mg-05 left one of the party's six mail slots in use by nobody, while MIMIEN still points
at it. When every other party member holds mail too, giving MIMIEN a Retro Mail fails half way: the
game opens the mail editor on MIMIEN's old mail, and leaving the editor without changing a word
"returns" MIMIEN's held item to the bag without taking it from MIMIEN. The bag gains one of that item
and loses the Retro Mail.

## Before you start

The save must be the one mg-05 left: the glitch active, MIMIEN holding the recycled Leppa Berry, on
Route 16. You also need a full party of six (the five members other than MIMIEN will hold mail), two
Antidotes in the bag (one for MIMIEN to hold, mg-05a buys them), and money for 8 Retro Mail.

What the plan needs, as the pre-flight checks it (generated from the plan):

<!-- generated:needs mg-06 -->
- 0 free party slots
- party includes mr-mime, pidgey
- pidgey in the party (fly)
- mr-mime in the party (party_swap)
- money at least ¥400 (all the purchases)
- antidote at least x1 (give_bag_item)
- at the start, Route16
<!-- /generated -->

## Running it

Straight after mg-05, or on its own from the mg-05 save:

<!-- generated:commands mg-06 -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.mail_glitch --from mg-06 --to mg-06 --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from mg-06 --to mg-06 --preflight-only
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from mg-06 --to mg-06
```
<!-- /generated -->

On mGBA the start state is `mg-06.start.ss` in `GAMEPILOT_STATES`, which a passing mg-05 run in
verification mode leaves there. On the Switch it is the game's save, which a passing mg-05 run
writes. To run activation and duplication in one go, use `--from mg-01 --to mg-06`.

## What happens

<!-- generated:checkpoints mg-06 -->
| Checkpoint | What its plan does |
|---|---|
| mg-06 | Use the Mail Glitch: read the glitched mail, duplicate one Antidote |

<!-- plans: 10d5a4087d10 -->
<!-- /generated -->

In plain words:

1. Flies to Celadon and buys 8 Retro Mail on the Department Store's 4th floor: five to fill the
   party's mail, one for the proof, one per copy, one spare.
2. Puts MIMIEN in party slot 1 and gives each of the other five a Retro Mail with one word on it.
   It checks the party screen: MIMIEN shows a held item, the other five show mail.
3. **Proof that the glitch works.** Gives a Retro Mail to MIMIEN. The mail editor must open showing
   ABRA, the word mg-05 wrote. A blank editor or `???` means the glitch is not active: the run stops
   and nothing is saved. Leaving the editor copies MIMIEN's Leppa Berry once, as a side effect.
4. Gives MIMIEN an Antidote (the Leppa Berry goes back to the Berry Pouch) and moves the Retro Mail
   to the top of the Items pocket.
5. **The copy.** One round of the duplication loop: give Retro Mail to MIMIEN, say YES to switching,
   leave the editor unchanged. The Antidote count goes up by one.
6. Checks the party again (the five mails stay on) and saves.

## How long it takes

About 12 minutes on the Switch, most of it the walk to the Department Store and handing out the
mail.

## When it stops

Nothing is saved until every check has passed. On the Switch a failed run soft-resets to the mg-05
save, so the only loss is the Retro Mail bought in that run; rerun the same command. On mGBA the
start state is untouched.

<!-- generated:preflight mg-06 -->
| Resume from | The pre-flight checks |
|---|---|
| mg-06 | party includes mr-mime, pidgey; pidgey in the party (fly); mr-mime in the party (party_swap); money at least ¥400 (mart); antidote at least x1 (give_bag_item); at the start, Route16 |
<!-- /generated -->

If the proof step stopped the run (a blank editor or `???`), the glitch is not active on that save:
run mg-05 again, from the end of mg-05a (`--from mg-05a --to mg-06`).

## Known limits

- One copy of one item (an Antidote) per run. Choosing the item and the number of copies comes with
  the Rare Candy programs.
- The program stops before Retro Mail runs out; at zero, the game would act on the next item in the
  pocket.
- The five filler mails stay on the party: later copies need them. Do not deposit MIMIEN or take its
  item through the PC, which resets its mail.
- A stack of 999 cannot grow: that round copies nothing (and does no harm).
- FireRed only, English only.
