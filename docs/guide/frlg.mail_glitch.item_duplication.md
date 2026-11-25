# Mail Glitch: item duplication (FireRed)

The second half of checkpoint 08-activate-and-verify of the Mail Glitch program. Once Lea & Jed's
battle has turned the glitch on (the first half, see [Mail Glitch: activation](frlg.mail_glitch.md)),
the checkpoint goes straight on: it proves the glitch is there by reading the glitched mail, then
copies one item, one Antidote today. The game is saved only after that, never between the battle
and the copy.

**What you get.** One more Antidote in the bag, and a party set up for more copies: MIMIEN in slot 1,
the other five each holding a Retro Mail. Each copy costs one Retro Mail ($50 at the Celadon
Department Store).

**Coming next** (not on `main` yet): Supplies (`frlg.supplies`) and Team Training
(`frlg.team_training`) run the same loop many times to duplicate Rare Candies.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## How it works, in short

The battle left one of the party's six mail slots in use by nobody, while MIMIEN still points
at it. When every other party member holds mail too, giving MIMIEN a Retro Mail fails half way: the
game opens the mail editor on MIMIEN's old mail, and leaving the editor without changing a word
"returns" MIMIEN's held item to the bag without taking it from MIMIEN. The bag gains one of that item
and loses the Retro Mail.

## Before you start

The checkpoint starts where 07-glitch-prep ends: on Route 16 one tile outside Lea's view, with
CH'DING, Blastoise (holding the Leppa Berry, its Blizzard out of PP) and MIMIEN (holding a Retro
Mail) in slots 1 to 3. You also need a full party of six (the five members other than MIMIEN will
hold mail), two Antidotes in the bag (one for MIMIEN to hold, 07-glitch-prep buys them), and money
for 8 Retro Mail.

What the plan needs, as the pre-flight checks it (generated from the plan):

<!-- generated:needs 08-activate-and-verify -->
- 0 free party slots
- party includes pidgey, farfetchd in slot 1, blastoise in slot 2, mr-mime in slot 3
- blastoise in the party (mail_glitch_double_battle)
- farfetchd in the party (mail_glitch_double_battle)
- mr-mime in the party (mail_glitch_double_battle)
- pidgey in the party (fly)
- money at least ¥400 (all the purchases)
- antidote at least x1 (give_bag_item)
- at the start, Route16
<!-- /generated -->

## Running it

Straight after 07-glitch-prep, or on its own from the 07-glitch-prep save:

<!-- generated:commands 08-activate-and-verify -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.mail_glitch --from 08-activate-and-verify --to 08-activate-and-verify --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from 08-activate-and-verify --to 08-activate-and-verify --preflight-only
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from 08-activate-and-verify --to 08-activate-and-verify
```
<!-- /generated -->

On mGBA the start state is `08-activate-and-verify.start.ss` in `GAMEPILOT_STATES`, which a
passing 07-glitch-prep run in verification mode leaves there. On the Switch it is the game's save,
which a passing 07-glitch-prep run writes. To run the whole program in one go, use
`--from 01-celadon-setup --to 08-activate-and-verify`.

## What happens

<!-- generated:checkpoints 08-activate-and-verify -->
| Checkpoint | What its plan does |
|---|---|
| 08-activate-and-verify | Turn the Mail Glitch on against Lea & Jed on Route 16, read the glitched mail, duplicate one Antidote |

<!-- plans: 096c63877d33 -->
<!-- /generated -->

In plain words, after the battle and the check that MIMIEN shows a held item:

1. Flies to Celadon and buys 8 Retro Mail on the Department Store's 4th floor: five to fill the
   party's mail, one for the proof, one per copy, one spare.
2. Puts MIMIEN in party slot 1 and gives each of the other five a Retro Mail with one word on it.
   It checks the party screen: MIMIEN shows a held item, the other five show mail.
3. **Proof that the glitch works.** Gives a Retro Mail to MIMIEN. The mail editor must open showing
   ABRA, the word on the mail the battle knocked off. A blank editor or `???` means the glitch is
   not active: the run stops and nothing is saved. Leaving the editor copies MIMIEN's Leppa Berry
   once, as a side effect.
4. Gives MIMIEN an Antidote (the Leppa Berry goes back to the Berry Pouch) and moves the Retro Mail
   to the top of the Items pocket.
5. **The copy.** One round of the duplication loop: give Retro Mail to MIMIEN, say YES to switching,
   leave the editor unchanged. The Antidote count goes up by one.
6. Checks the party again (the five mails stay on) and saves.

## How long it takes

About 12 minutes on the Switch after the battle, most of it the walk to the Department Store and
handing out the mail.

## When it stops

Nothing is saved until every check has passed. On the Switch a failed run soft-resets to the
07-glitch-prep save, before the battle, so the only loss is the Retro Mail bought in that run; rerun
the same command, which fights the battle again. On mGBA the start state is untouched.

<!-- generated:preflight 08-activate-and-verify -->
| Resume from | The pre-flight checks |
|---|---|
| 08-activate-and-verify | party includes pidgey, farfetchd in slot 1, blastoise in slot 2, mr-mime in slot 3; blastoise in the party (mail_glitch_double_battle); farfetchd in the party (mail_glitch_double_battle); mr-mime in the party (mail_glitch_double_battle); pidgey in the party (fly); money at least ¥400 (mart); antidote at least x1 (give_bag_item); at the start, Route16 |
<!-- /generated -->

If the proof step stopped the run (a blank editor or `???`), the battle did not turn the glitch on:
rerun the same command, which starts again before the battle. If the arranged party or the Leppa
Berry is gone, run 07-glitch-prep first (`--from 07-glitch-prep --to 08-activate-and-verify`).

## Known limits

- One copy of one item (an Antidote) per run. Choosing the item and the number of copies comes with
  the Rare Candy programs.
- The program stops before Retro Mail runs out; at zero, the game would act on the next item in the
  pocket.
- The five filler mails stay on the party: later copies need them. Do not deposit MIMIEN or take its
  item through the PC, which resets its mail.
- A stack of 999 cannot grow: that round copies nothing (and does no harm).
- FireRed only, English only.
