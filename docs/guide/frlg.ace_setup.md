# ACE Setup

The first half of arbitrary code execution (ACE) in FireRed, after the Mail Glitch: it gets the
save to the point where Box 3 slot 1 holds the glitch Pokémon that the ACE payloads are run
through (species 0x0351, from pomeg-letterbombers' Post-E4 route). The second half, typing a
payload into the box names and running it (Master Balls and Luxury Balls), is the execution
program, which is not written yet.

**What you get.** A male Lv 100 Pokémon with a ? picture and a garbled name in Box 3 slot 1, and
a Magikarp in your party (seen in the Pokédex). MIMIEN goes to Box 1 of the PC.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

The program starts where the Mail Glitch program ends: Mail Glitch 08-activate-and-verify done,
standing on the Celadon Department Store's ground floor below the lift. You need $500 for the
Magikarp, a Retro Mail in the bag, Pidgey to fly, and an empty Box 3 slot 1. The game must be past
the Hall of Fame (the two move word groups unlock then).

What the plan needs, as the pre-flight checks it (generated from the plan):

<!-- generated:needs ace-01 -->
- 0 free party slots
- pidgey in the party (fly)
- mr-mime in the party (pc_deposit)
- at the start, CeladonCity_DepartmentStore_1F
<!-- /generated -->

## Running it

<!-- generated:commands -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.ace_setup --from ace-01 --to ace-02 --mode verification
```
<!-- /generated -->

On mGBA the start state is `ace-01.start.ss` in `GAMEPILOT_STATES`: a copy of the state Mail
Glitch 08-activate-and-verify ends in.

## What happens

<!-- generated:checkpoints -->
| Checkpoint | What its plan does |
|---|---|
| ace-01 | Magikarp seen: MIMIEN to the PC, a Magikarp bought at the Route 4 Pokemon Center |
| ace-02 | The ? Mail written BULK UP / CAPABLE / KARATE CHOP / MAGIKARP: species 0x0351 in Box 3 slot 1 |

<!-- plans: d638c4f57fc1 -->
<!-- /generated -->

In plain words:

1. Flies to the Route 4 Pokémon Center, puts MIMIEN in the PC and buys a Magikarp from the man
   by the door ($500). The Magikarp joins the party, and with it Magikarp counts as seen.
2. Opens the PC and checks that Box 3 slot 1 is empty.
3. Gives the Magikarp a Retro Mail. Because every party mail slot is in use, the game opens the
   "? Mail", nine fields of `???`; the program checks it sees them. It writes
   `BULK UP / CAPABLE / KARATE CHOP / MAGIKARP` (MOVE 2, ACTIONS, MOVE 1 and POKéMON groups),
   reads every word back, and only then confirms. This is the step that cannot be undone.
4. Opens the PC again: Box 3 slot 1 now shows a male Lv 100 Pokémon.

## How long it takes

About four minutes on mGBA at normal speed.

## When it stops

Nothing is confirmed until every word reads right, and on mGBA every run starts again from the
saved start state, so a stopped run changes nothing. The second checkpoint's start state (after
the Magikarp) is the backup from before the ? Mail.

<!-- generated:preflight ace-01 -->
| Resume from | The pre-flight checks |
|---|---|
| ace-01 | pidgey in the party (fly); mr-mime in the party (pc_deposit); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits

- mGBA only for now; English FireRed (proven on version 1.1).
- MIMIEN leaves the party, so the Mail Glitch's item duplication now goes through the ? Mail:
  its editor shows BULK UP, not ABRA.
- Box 3 is told by its default Desert wallpaper; a changed wallpaper stops the check.
- The species itself is not read from the screen: the check is the level, the gender and that the
  slot is filled.
