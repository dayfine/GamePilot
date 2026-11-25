# Programs as goals (draft, 2026-11-24)

Today every program is a fixed chain of hand-written checkpoint plans: su-01 always buys 100 Retro
Mail and 5 Super Repels, tt-01 always picks up Route 6's Rare Candy. This note proposes programs that
state a goal (what the save should hold when they finish), take a checked configuration, check their
preconditions, and get their plans partly generated from data. It answers the three review threads
on #25 (Supplies' configuration, Team Training's checkpoints, the repeated "go to Dept. Store 4F")
and is for review before any code. The choices below are recommendations; the open questions are at
the end.

## Where we are

- A **plan** (`pokesim-authored-checkpoint/1`, decoded by `pokemon/story`) is a list of events from
  one save to the next, with postconditions the runner checks at the end, `retries`, and `repeat`
  (run the round again until the postconditions hold).
- The **pre-flight** (`frlg/story/plan_needs.ml`, `preflight.ml`) already derives what a plan needs
  from its event args: the members an action names, Cut, the money its purchases cost (prices from
  `kanto_mart_stocks.json`, made from pokefirered), bag items it uses, the place. It reads them off
  the save (Trainer Card money, bag, party summary) and refuses when one does not hold.
- **Walks** are planned from PokemonSimulation's maps, so no path is copied. But the sequence of
  targets is: "stand below the 1F lift door, `lift_floor` 1F to 4F, walk to the clerk, back to the
  lift, ride down" appears in mg-01, mg-06 and su-01, each with its own tiles.
- **Skipping** exists per event only (`skip_if`, flags fixed by the run's configuration), not per
  checkpoint, and nothing tries an alternative when an event cannot succeed.
- **Configuration** does not exist: the registry (`src/program_registry`) gives each program a name,
  doc and plans folder, and a run takes `--from`/`--to` checkpoint ids.

## 1. A program is a goal, a configuration and plans

A program has:

- a **goal**: postconditions on the save at its end (`retro-mail` at least 100; Blastoise at least
  Lv 100), the same postcondition type checkpoints use;
- a **configuration**: the few choices a user makes, checked against game data before anything
  runs;
- **plans**: hand-written where the story is fixed, generated where the configuration decides them.

What stays hand-written: the Mail Glitch (mg-01 to mg-06 is a fixed story; its order, tiles and
battles are the point), every action's code (`mart`, `lift_floor`, `fly`, `duplicate_item`,
`candy_level`), and one-off routes that need a person's judgement (where to use a Super Repel). What
is generated: plans whose content is a function of the configuration, today only Supplies (which
marts, in which order, how many of each) and Team Training's candy count. A generator is a small
OCaml function per program that writes ordinary plans; the runner, pre-flight, event states, guides
(#28) and the watch page see plans exactly as they do now, and the generated plans are kept in the
run's folder so a run can be read and replayed later.

**Where the configuration lives.** Each configurable program has a default configuration file beside
its plans (`src/games/<game>/programs/<program>/config.json`) and a description of its fields in its
registry entry (name, type, default, one line of help), so `gamepilot programs` can print them. A run
takes `--config FILE` and repeated `--set field=value` over the defaults; `run.json` records the
configuration used. The Control UI can offer the same fields later.

**Checked against game data, before the console is touched.** Supplies' configuration is a list of
(item, count):

```json
{ "buy": [ { "item": "retro-mail", "count": 100 }, { "item": "super-repel", "count": 5 } ] }
```

Each line is checked: the item exists (`item_names_eng.txt`); some mart in `kanto_mart_stocks.json`
sells it ("master-ball: no Kanto mart sells it"); the count is 1 to 999 (the bag's stack). All
errors are listed at once and nothing runs. The generator then picks, per item, the first mart in a
fixed preference list that sells it (Celadon Dept. Store first: one Fly covers several floors), groups
the lines by mart, orders the marts by Fly town, splits counts above 99 into lines of at most 99
(as su-01's 50 + 50), and adds the total cost as a money need. The stock table has 11 marts today;
the Dept. Store 2F (two counters, the most common items) is missing and comes with this step.

## 2. Preconditions are checked facts

A precondition is a fact read off the save before the first event, as the pre-flight does now. The
plan-derived needs stay; the program adds the ones its goal implies. Each maps to a reader we have
or one small addition:

| Precondition | Read by | Today |
|---|---|---|
| Money at least the purchases' cost | Trainer Card front (`trainer_card_money.ml`); a Mart's money box when standing at a clerk | derived from `mart` args |
| Fly: a member that knows it | party summary moves (`Party_summary`) | `fly` names the member |
| Fly: the badge | not read; the Trainer Card back shows badges (a new reader) | not checked |
| Item count (`retro-mail` at least N) | bag read | derived from `duplicate_item` args (#25) |
| A member at a level | summary (`Member_level`) | postconditions only |
| Free party slots | party read (`Party_room`) | yes |

**A failed precondition refuses the run** and says which program provides it, with the command
line: "needs `retro-mail` at least 99, the bag has 12: run `frlg.supplies --set
buy=retro-mail:87`". To do that, a program declares what it provides (Supplies: any item a mart sells;
Team Training's candy checkpoint: `rare-candy`). Running the provider automatically first is a later
step, behind a flag, once refusing has proved the declarations right. Following the earlier
direction: stocking is its own program, and the programs that spend stock check a floor and buy more
than one run needs, so a rerun does not stop for one missing mail.

## 3. Places: a table of named spots, expanded before the run

A **place** is a named spot: map, tile, facing.

```json
{ "dept_store_4f_clerk": { "map": "CeladonCity_DepartmentStore_4F", "tile": [3, 11], "facing": "south" },
  "dept_store_1f_save": { "map": "CeladonCity_DepartmentStore_1F", "tile": [6, 2], "facing": "south" } }
```

A plan says where to go, not how: a route whose target is a place name (`"target": { "place":
"dept_store_4f_clerk" }`). When a plan is loaded, before the runner sees it, the expansion turns it
into the events written by hand today: a route to the lift tile on the current floor, `lift_floor`
from that floor to the target's, a route to the target. The current position is known at that point
from the checkpoint's start and each earlier event's target or `declared_after`, as it is now.
Expanded events get ids derived from the original (`to_4f_clerk`, `to_4f_clerk.lift`,
`to_4f_clerk.walk`), so logs and event states stay readable.

This is data composition, not a code abstraction: the table is data, the lift ride stays the
existing `Lift_ride` code, and the only new code is the expansion (a pure function from a plan to a
plan, tested without a game). Fly stays an explicit event in the first step; expanding "place in
another town" into Fly + walk is the same mechanism and can follow once the lift case has run.

The table lives in GamePilot (`src/games/frlg/assets/kanto_places.json`), since the names are our
automation's, not the map's; a test checks every place against PokemonSimulation's map (the tile is
walkable, the facing points at an NPC or door where the name says so). Maps are still read from
PokemonSimulation, never copied.

## 4. Checkpoints that skip and fall back

Two additions to the checkpoint, both in `pokemon/story`:

- **`skip_when`**: postconditions read at the checkpoint's start; when they hold, the checkpoint
  is skipped and counted as passed. It reuses the postcondition reads, so a rerun resumes where the
  save is.
- **`alternatives`**: a list of ways to reach the same postconditions, tried in order. An
  alternative that ends with "nothing there" moves on to the next one; any other failure retries the
  same one under `retries`, as now. Telling the two apart needs `pick_up_item` to fail with its own
  reason (`no_item`) when no text box shows.

Team Training (the worked example) becomes three checkpoints:

| Checkpoint | Skipped when | Does |
|---|---|---|
| tt-01 get a Rare Candy | the bag holds at least 1 `rare-candy` | tries hidden candies in order, nearest the save spot first: Route 6 (19, 5), Cerulean City (18, 7), Route 9 (63, 2), Route 12 (9, 116) (from PokemonSimulation's `hidden_items`). A hidden item picked up once is gone for good and the save does not tell us which, so each spot is tried until one yields |
| tt-02 duplicate | `rare-candy` at least N | gives the candy to slot 1, Retro Mail to the top, `duplicate_item` until N; needs `retro-mail` at least rounds + 1 (Supplies provides it) |
| tt-03 level | every target level reached | `candy_level` (#26) per member in the configuration |

Configuration: the targets (`[ { "species": "blastoise", "level": 100 } ]`) and a margin. N is the
candies the targets need from the levels read at the pre-flight, plus the margin ("dup more than
needed"). If all four spots are empty, tt-01 fails and says so; no mart sells Rare Candies.

## 5. Migration, one concern per PR

Each step runs on mGBA (3 passes from its start state) before console B, and leaves every existing
plan working.

1. **Places.** The table, route targets that name a place, the expansion with the lift case. mg-01,
   mg-06 and su-01 rewritten to use it; a test checks that each expands to the same walks, rides and
   end poses as today's hand-written plan. mGBA: su-01 and mg-06 once each, then su-01 on the Switch.
2. **Program configuration.** Registry field descriptions, `config.json`, `--config`/`--set`, the
   configuration in `run.json`. No program uses it yet except a test.
3. **Configurable Supplies.** The checked item list, mart choice and generator, the Dept. Store 2F in
   the stock table. su-01 becomes the default configuration's generated plan; a test checks that it
   equals today's su-01. mGBA: the default and one two-mart list.
4. **Checkpoint skip and alternatives** in `pokemon/story`, and `pick_up_item`'s `no_item`. Tested with
   a scripted game, no plan changes.
5. **Team Training in three checkpoints** (after #26): tt-01 to tt-03 as above. mGBA from a save with
   the candy, one without it, and one where Route 6's candy is already gone.
6. **Preconditions name their provider.** Programs declare what they provide; a refused pre-flight
   prints the provider's command line. Automatic chaining stays a later question.

## Open questions

1. **Plan format.** A route target that names a place, `skip_when` and `alternatives` are additions
   to PokemonSimulation's plan format. Recommendation: GamePilot's additions for now, as `knows`,
   `money` and `marks` were, expanded or read only here; propose them to PokemonSimulation once they
   have run on the console.
2. **Where the places table lives.** Recommendation: GamePilot, checked against PokemonSimulation's
   maps by a test; move it to PokemonSimulation if its tools need the names.
3. **May a generator read the save?** Team Training's candy count depends on current levels.
   Recommendation: yes, only through the pre-flight's reads, and the generated plans are saved with
   the run so the run can still be replayed.
4. **Failed precondition: refuse or chain?** Recommendation: refuse with the provider's command line
   first; chaining behind a flag later.
5. **The Fly badge.** No reader yet. Recommendation: take "a member knows Fly" as enough for now
   (FRLG asks for the Thunder Badge, and every save we run is well past it), and add the Trainer
   Card badge reader when a program runs on an earlier save.
6. **Mart choice.** A fixed preference list (Celadon first) or the cheapest trip worked out from Fly
   towns? Recommendation: the fixed list; the configuration may name a mart to override it.
