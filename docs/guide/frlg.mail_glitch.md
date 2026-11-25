# Mail Glitch: activation (FireRed)

This program sets up and triggers the Mail Glitch on a post-game FireRed save, then uses it once to
copy an item. This page covers the whole run, checkpoints 01-celadon-setup to
08-activate-and-verify. The last one triggers the glitch and, in the same checkpoint, proves it by
copying one item before anything is saved; the copying has its own page:
[Item duplication](frlg.mail_glitch.item_duplication.md).

How the glitch works, step by step: the Pomeg Letterbombers'
[Mail Glitch notes](https://pomeg-letterbombers.github.io/pokemon-ace-notes/mail-glitch/).

**What you get.** After the battle in 08-activate-and-verify your Mr. Mime (MIMIEN, from an
in-game trade) holds a Leppa Berry where its mail used to be, and one of the party's mail slots is
"leaked": the game thinks it is in use, but no Pokémon holds it. That leaked slot is what makes item duplication work. Along the way
you also get the Coin Case, CH'DING (a traded Farfetch'd that knows Knock Off) and MIMIEN at level 33
or more with Recycle.

**Coming next** (not on `main` yet): Supplies (`frlg.supplies`) and Team Training
(`frlg.team_training`) use the glitch to duplicate Rare Candies.

<!-- generated:backends -->
Runs on: mGBA, the Switch (in its GBA app).
<!-- /generated -->

## Before you start

You need:

- **FireRed, English.** LeafGreen's Game Corner prizes differ, and the Japanese game stores mail
  differently.
- **A post-game save**: the plans walk through Celadon, Vermilion, Route 2, Lavender, the Pokémon
  Tower and Victory Road, and fly between towns.
- **Blastoise** (it fights the grind's battles and Lea & Jed) and **Pidgey** (it flies; the plans pick Fly's
  user by species) in the party, and some member that knows **Cut**.
- **Two free party slots**: Abra (a Game Corner prize) joins in 01-celadon-setup and Spearow (caught on Route
  16) in 02-trade-farfetchd. On the Switch, `--make-room MAP` can deposit members for you (see below).
- **Enough money** for every purchase on the way.
- **Where to stand**: outdoors, somewhere you can Fly from. The first thing 01-celadon-setup does is Fly to
  Celadon City.

What the plans need, as the pre-flight checks it (generated from the plans):

<!-- generated:needs 01-celadon-setup..08-activate-and-verify -->
- 2 free party slots (joining: abra in 01-celadon-setup, spearow in 02-trade-farfetchd)
- pidgey in the party (fly)
- blastoise in the party (grind)
- a member knows cut (cut_tree)
- the thunder badge (fly)
- the cascade badge (cut_tree)
- money at least ¥10350 (all the purchases)
- poke-ball at least x1 (capture)
- at the start, CeladonCity
<!-- /generated -->

On the Switch, the pre-flight reads your save and checks this list before the first checkpoint
runs. A full party makes it name the members to deposit; it never picks a member the plans use, the
lead, or one that knows a field move.

## Running it

Build first (`cd src && opam exec -- dune build`; on the Switch, also the daemon), and set the
`GAMEPILOT_*` variables described in the repository's `README.md` (mGBA) and
`docs/switch-bring-up.md` (the Switch).

<!-- generated:commands 01-celadon-setup..08-activate-and-verify -->
```sh
# mGBA: each checkpoint three times from its start state, two must pass
sh run/run_checkpoints_on_mgba.sh --program frlg.mail_glitch --from 01-celadon-setup --to 08-activate-and-verify --mode verification

# the Switch: check the save first, then run (each checkpoint once, saved when it passes)
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from 01-celadon-setup --to 08-activate-and-verify --preflight-only
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from 01-celadon-setup --to 08-activate-and-verify
```
<!-- /generated -->

**On mGBA** the run starts from a save state, not from the game's save: save one in mGBA (File >
Save State File) with the player standing where Fly works, as `01-celadon-setup.start.ss` in your
`GAMEPILOT_STATES` folder. Each checkpoint then runs three times from its start state, needs two
passes, and its last passing end becomes the next checkpoint's start state (`02-trade-farfetchd.start.ss`, ...).

**On the Switch** the run starts from the game's last save. Load your save in FireRed and stand
where Fly works, then save in the game. Each checkpoint runs once; when it passes, the program saves
in the game, and the next checkpoint starts from that save. If the party is full, add
`--make-room MAP` (MAP: the map you saved on, e.g. `PalletTown`) to let the program deposit
members at the nearest Pokémon Center's PC first.

Each run prints the address of its watch page, where you can follow the game, the checkpoint's
steps and its log, and stop it.

## What happens

<!-- generated:checkpoints 01-celadon-setup..08-activate-and-verify -->
| Checkpoint | What its plan does |
|---|---|
| 01-celadon-setup | Celadon setup: Fly to Celadon, Coin Case, Retro Mail on Dept Store 4F, buy 200 coins, redeem Abra |
| 02-trade-farfetchd | Catch Spearow on Route 16, collect Sitrus Berry on Route 6, trade for CH'DING in Vermilion |
| 03-trade-mr-mime | Trade Abra for MIMIEN on Route 2, buy Revives in Lavender Mart, heal at Lavender Center |
| 04-grind-farfetchd | Grinding, part 1: CH'DING Knock Off (skips when known), Escape Rope, Fly to Indigo Plateau and heal at its nurse |
| 05-grind-mr-mime | Grinding, part 2 (repeats): one round of MIMIEN's grind at Victory Road 2F, from the Indigo Plateau nurse and back to heal (repeats, at most 20 rounds) |
| 06-grind-return | Grinding, part 3: from the Indigo Plateau nurse, Fly back to Lavender Town for 07-glitch-prep |
| 07-glitch-prep | Prepare Leppa and Retro Mail for Lea & Jed on Route 16 |
| 08-activate-and-verify | Turn the Mail Glitch on against Lea & Jed on Route 16, read the glitched mail, duplicate one Antidote |

<!-- plans: e280cf67989c -->
<!-- /generated -->

In plain words:

1. **01-celadon-setup, Celadon.** Flies to Celadon, gets the Coin Case in the restaurant, buys two Retro Mail
   on the Department Store's 4th floor, buys 200 coins and trades them for an Abra.
2. **02-trade-farfetchd, CH'DING.** Cuts into Route 16's grass and catches a Spearow, picks up the hidden Sitrus
   Berry on Route 6, and trades the Spearow for CH'DING in Vermilion.
3. **03-trade-mr-mime, MIMIEN.** Trades Abra for MIMIEN on Route 2, buys Revives and an Escape Rope in
   Lavender, and heals.
4. **04-grind-farfetchd to 06-grind-return, grinding.** Makes sure CH'DING knows Knock Off (it usually does already),
   then flies to Indigo Plateau and trains MIMIEN on Victory Road 2F, switching it out for Blastoise
   in each battle, until it reaches level 33 and learns Recycle (into its first move slot). 05-grind-mr-mime
   is one round: from the Indigo Plateau nurse, up to 7 battles, back to heal. It repeats until
   MIMIEN is ready. Then the program flies back to Lavender.
5. **07-glitch-prep, preparation.** Buys medicine, picks up the hidden Leppa Berry on Route 8, uses up
   Blastoise's Blizzard PP in wild battles, flies to Celadon and walks up Route 16 to just outside
   the trainers' view. It puts CH'DING, Blastoise and MIMIEN in slots 1 to 3, and gives Blastoise
   the Leppa Berry and MIMIEN a Retro Mail with one word on it.
6. **08-activate-and-verify, the glitch.** The double battle against Lea & Jed: Blastoise eats its
   Leppa Berry, MIMIEN switches into its place, CH'DING knocks off MIMIEN's mail, and MIMIEN uses
   Recycle to get the berry back. The program checks that MIMIEN shows a held item, then, without
   saving, goes straight on to read the glitched mail and copy one Antidote
   ([Item duplication](frlg.mail_glitch.item_duplication.md)). The game is saved only once the copy
   has worked, so a save right after the battle never exists.

## How long it takes

On the Switch, about three hours from 01-celadon-setup to 08-activate-and-verify. Most of that is
05-grind-mr-mime: one round takes 10 to 14 minutes, and a MIMIEN fresh from the trade needs about a dozen rounds. The other checkpoints take
2 to 15 minutes each. On mGBA each checkpoint runs three times; `--speed S` runs the emulator S times
as fast.

## When it stops

A checkpoint that fails stops the series, and nothing is saved past the last checkpoint that
passed. The run's folder (in `GAMEPILOT_RUNS`) has the failure screenshot and the log, and the watch
page's list of past runs shows them.

To carry on, fix the cause if there is one (a member missing, not enough money), then rerun the same
command with `--from` set to the checkpoint that failed:

```sh
sh run/run_checkpoints_on_switch.sh --program frlg.mail_glitch --from 05-grind-mr-mime --to 08-activate-and-verify
```

On the Switch the game is back at its last save, which is the failed checkpoint's start. On mGBA
the failed checkpoint's start state is still there. A stopped 05-grind-mr-mime loses at most the
round it was in: every finished round is saved at the Indigo Plateau nurse. A stopped
08-activate-and-verify starts again before the battle, one tile outside Lea's view.

Before a resumed run, the pre-flight checks what that checkpoint needs, including what the
checkpoint before it promised:

<!-- generated:preflight 01-celadon-setup..08-activate-and-verify -->
| Resume from | The pre-flight checks |
|---|---|
| 01-celadon-setup | pidgey in the party (fly); the thunder badge (fly); money at least ¥4100 (mart, buy_coins); at the start, CeladonCity |
| 02-trade-farfetchd | party includes blastoise, pidgey, abra; pidgey in the party (fly); a member knows cut (cut_tree); the cascade badge (cut_tree); the thunder badge (fly); poke-ball at least x1 (capture); at the start, CeladonCity |
| 03-trade-mr-mime | party includes blastoise, pidgey, abra, farfetchd; pidgey in the party (fly); abra in the party (ingame_trade); a member knows cut (cut_tree); the thunder badge (fly); the cascade badge (cut_tree); money at least ¥3550 (mart); at the start, VermilionCity |
| 04-grind-farfetchd | party includes blastoise, pidgey, mr-mime, farfetchd; farfetchd in the party (grind); blastoise in the party (grind); pidgey in the party (fly); the thunder badge (fly); escape-rope at least x1 (use_item); at the start, LavenderTown_PokemonCenter_1F |
| 05-grind-mr-mime | party includes blastoise, pidgey, mr-mime, farfetchd; mr-mime in the party (grind); blastoise in the party (grind); at the start, IndigoPlateau_PokemonCenter_1F |
| 06-grind-return | party includes blastoise, pidgey, mr-mime, farfetchd; pidgey in the party (fly); the thunder badge (fly); at the start, IndigoPlateau_PokemonCenter_1F |
| 07-glitch-prep | party includes blastoise, pidgey, mr-mime, farfetchd; blastoise in the party (party_swap); pidgey in the party (fly); farfetchd in the party (party_swap); mr-mime in the party (party_swap); a member knows cut (cut_tree); the cascade badge (cut_tree); the thunder badge (fly); money at least ¥2300 (mart); retro-mail at least x1 (give_bag_item); at the start, LavenderTown |
| 08-activate-and-verify | party includes pidgey, farfetchd in slot 1, blastoise in slot 2, mr-mime in slot 3; blastoise in the party (mail_glitch_double_battle); farfetchd in the party (mail_glitch_double_battle); mr-mime in the party (mail_glitch_double_battle); pidgey in the party (fly); the thunder badge (fly); money at least ¥400 (mart); antidote at least x1 (give_bag_item); at the start, Route16 |
<!-- /generated -->

If the run failed during the soft reset itself, the game is left where it stopped: look at the
screen, back out of any menu, and rerun. Never answer YES to "There is already a saved file" by hand.

## Known limits

- FireRed only, English only.
- The pre-flight compares where you stand with a screenshot kept from an earlier run. The first time
  a save runs on the Switch there is none, so the place reads NOT READ and the pre-flight stops:
  check by eye that you stand where the plan starts and add `--no-preflight` for that first run.
- The Switch is shared: only one program may drive it at a time. The Switch script takes the
  console's lock and refuses to start while another program holds the controller or the capture
  card.
- The grind assumes MIMIEN reaches level 33 within 20 rounds; from a very low level it may need more
  (run 05-grind-mr-mime again from its last save).
- MIMIEN must stay in the party after the battle in 08-activate-and-verify. Depositing or trading
  it resets its mail, and duplication no longer works.
