# ACE Setup

The first half of arbitrary code execution (ACE) in FireRed, after the Mail Glitch: it puts the
glitch Pokémon the ACE payloads run through (species 0x0351, from pomeg-letterbombers' Post-E4
route) in Box 3 slot 1. The second half, the execution program, is not written yet.

**What you get.** A male Lv 100 Pokémon with a ? picture and a garbled name in Box 3 slot 1, a
Magikarp in your party (seen in the Pokédex), and one party member moved to the PC.

<!-- generated:backends -->
Runs on: mGBA.
<!-- /generated -->

## Before you start

What the save needs:

- The Mail Glitch active: all six party mail records taken (Mail Glitch through
  08-activate-and-verify).
- The game cleared (the Hall of Fame entered): the move word groups unlock then.
- Box 3 slot 1 empty: the ? Mail writes over it.
- Magikarp seen, for the word MAGIKARP. The program buys one ($500).
- A party member whose mail index is 0xFF (it has not held Mail since it joined), to receive the
  Retro Mail so the ? Mail opens. The bought Magikarp is that member.
- A free party slot for it: the program puts a member not holding Mail in the PC.
- A member that knows Fly, a Retro Mail in the bag, and $500.
- Standing on the Celadon Department Store's ground floor below the lift, where Mail Glitch 08 ends.

The plan names the Fly user and the member to deposit by species, as the Mail Glitch save has them
(Pidgey and MIMIEN). What the pre-flight checks (generated from the plan):

<!-- generated:needs ace-01 -->
- 0 free party slots
- the Hall of Fame entered
- pidgey in the party (fly)
- mr-mime in the party (pc_deposit)
- mr-mime holds no Mail (pc_deposit)
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
| ace-01 | Magikarp seen and in the party: a free slot made at the Route 4 Pokemon Center's PC, a Magikarp bought there |
| ace-02 | The ? Mail written BULK UP / CAPABLE / KARATE CHOP / MAGIKARP: species 0x0351 in Box 3 slot 1 |

<!-- plans: 452c1c79ff39 -->
<!-- /generated -->

In plain words:

1. Flies to the Route 4 Pokémon Center, puts MIMIEN in the PC and buys a Magikarp from the man
   by the door ($500). The Magikarp joins the party, and with it Magikarp counts as seen.
2. Opens the PC and checks that Box 3 slot 1 is empty.
3. Gives the Magikarp a Retro Mail. Every party mail record is in use, so the game opens the
   "? Mail", nine fields of `???`. It writes `BULK UP / CAPABLE / KARATE CHOP / MAGIKARP`, reads
   every word back, and only then confirms. This is the step that cannot be undone.
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
| ace-01 | the Hall of Fame entered; pidgey in the party (fly); mr-mime in the party (pc_deposit); mr-mime holds no Mail (pc_deposit); at the start, CeladonCity_DepartmentStore_1F |
<!-- /generated -->

## Known limits

- mGBA only for now; English FireRed (proven on version 1.1).
- The Magikarp is bought even when it is already seen: the run cannot read the Pokédex's seen list.
- It starts at the Dept. Store, where Mail Glitch 08 ends. Any spot you can fly from would do, but
  a plan's start is one map and tile today.
- With MIMIEN in the PC, the Mail Glitch's item duplication goes through the ? Mail: its editor
  shows BULK UP, not ABRA.
- Box 3 is told by its default Desert wallpaper; a changed wallpaper stops the check.
- The species itself is not read from the screen: the check is the level, the gender and that the
  slot is filled.

## How it works

The route is pomeg-letterbombers'
[FRLG non-JPN Post-E4 route](https://pomeg-letterbombers.github.io/pokemon-ace-notes/frlg-non-jpn-post-e4-route/);
this program is step 1 of the dex collection build order (issue #15,
`docs/roadmap/frlg-ace-balls.md`).

**The ? Mail.** Giving Mail looks for a free party mail record (pret `GiveMailToMon`). With all
six taken it finds none and leaves the member's mail index as it was, and the editor opens on that
record. For a member with index 0xFF that is the save's record 0xFF, which lies on Box 3 slot 1.

**The words.** The message's first four words become that slot's personality (0x162E2753) and OT
ID (0x2A812402), so the slot decrypts as species 0x0351. MAGIKARP comes from the POKéMON group,
which lists only the species seen; MOVE 1 and MOVE 2 unlock with the game cleared.

**Why a member goes to the PC.** On the Mail Glitch save five members hold the filler mails and
MIMIEN still points at the leaked record 0, so no member has index 0xFF and the party is full. The
PC refuses a member holding Mail, so MIMIEN is the one deposited, and its stale index ends there.

**The pieces.** `Easy_chat_entry` writes words into the mail editor: the cursor goes down a row
at a time until its row shows the word, and each field is read back. The word lists are
`Frlg_text.Easy_chat_words`, extracted from pret. `Pc_box` walks from the PC to the MOVE POKéMON
box screen and back, one look at a time. `Ace_mail`'s `check_box_slot` moves the hand to the slot
and reads the box: its wallpaper, the PKMN DATA panel, the level and the male mark.

**Reader headroom.** The colour readers' thresholds and their headroom on 14 mGBA frames, each
under nine colour shifts, are in `src/games/frlg/readers/test/test_ace_readers.ml`. The word
arrow and the hand shadow are the thin ones; both are confirmed by a second read.

**For the execution program.** It needs a naming-screen typer (the payload is the box names) and
the trigger: MOVE POKéMON, SELECT for Relocate mode, swap any Pokémon with the 0x0351 twice. Box 13
slot 7 and every slot after it must be empty. Codes depend on the version (proven on BPRE 1.1),
and renamed boxes keep their wallpapers, so a box title reader is still missing.
