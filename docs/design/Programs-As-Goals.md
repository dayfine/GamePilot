# Programs as goals (draft, 2026-11-24)

Today every program is a fixed chain of hand-written checkpoint plans: su-01 always buys 100 Retro
Mail and 5 Super Repels, tt-01 always picks up Route 6's Rare Candy. This note proposes programs that
state a goal (what the save should hold when they finish), take a checked configuration, check their
preconditions, and get their plans partly generated from data. It answers the three review threads
on #25 (Supplies' configuration, Team Training's checkpoints, the repeated "go to Dept. Store 4F")
and is for review before any code. The decisions from its review (2026-11-24) are listed at the end,
with the two questions still open.

## Words

The levels, from what you run down to the wire. Code, docs and reviews use these words and no others
for these things.

| Level | What it is | Example |
|---|---|---|
| **Program** | What you run: registered, takes a configuration | Supplies, Team Training |
| **Goal** | What the program must achieve, as facts the runner can check on the save | at least 100 Retro Mail; Blastoise Lv 100 |
| **Checkpoints** | The chain the goal is split into. Each starts from a known save and ends in a checked state, so a failure resumes there | su-01; tt-01 → tt-02 → tt-03 |
| **Plan** | One checkpoint's script: its start, its events, its postconditions | `tt-01.plan.json` |
| **Event** | One entry of a plan: a walk or a game action | `fly_vermilion`, `duplicate_item` |
| **Game steps** | What an action reads and does on the screen (`game_steps`, the record a deciding module takes) | `open_list`, `find_battle` |
| **Inputs** | Button presses on the wire | A, DOWN, hold B |

A checkpoint repeats in two ways, neither of them a level: **runs** are retries of the same
checkpoint from its start ("2 of 3 runs must pass"), and **rounds** repeat a checkpoint until a
condition holds (mg-04b's grind rounds). The whole chain is "the program's checkpoints"; "plan"
always means one checkpoint's plan. The library that runs them is renamed from `story` to
`checkpoints` in its own PR before any of this is built.

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

**Where the configuration lives.** A run takes a goal file (`--goal FILE`); flags such as
`--set field=value` are shorthand decoded into the same value, so both get the same types and
errors. Each configurable program has one OCaml record for its configuration and one decoder over
`Json_field` that returns a `Result`; the registry entry holds the defaults. Errors give the path,
what was expected, what was read and a suggestion where there is one:

```
members[2].level: expected 1..100, got 101
members[0].species: "blastoize" is not a species; did you mean "blastoise"?
members[1]: gloom is not in the party (party: mr-mime, blastoise, ...)
```

Checks run in two passes: the file pass (shape, ranges, names) before anything starts, the game
pass (party, bag) at the start of the run, refusing as in section 2. `gamepilot goal describe
<program>` prints the fields, types, ranges, defaults and an example, from the same field
definitions the decoder uses; `gamepilot goal check FILE` checks a file without running. Tests pin
the text of each kind of error. No hand-kept JSON Schema and no ppx: neither gives the domain checks,
and a JSON Schema can be printed from the field definitions later if an editor needs one. `run.json`
records the configuration used, and the run's folder keeps a copy of the goal file.

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
| Fly: the badge | Trainer Card front (`Trainer_card_badges`); FireRed draws the badges on the front | a plan's declared `badges` precondition |
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

The table lives in GamePilot (`src/games/frlg/places/`). Where an object is (the nurse, a door, a
hidden item) is map data and stays in PokemonSimulation: a place names the object by its id there
and adds only what is ours, the tile we stand on to use it, the facing, and names such as
`dept_store_1f_save`. A test checks that every place resolves on PokemonSimulation's maps and that
its stand tile can be walked to. An object missing from PokemonSimulation's objects (a hidden item,
say) gets its tile in the table, marked as not in the maps yet, and a follow-up there. Coordinates
are never copied from the maps.

**Fragments and checkpoint templates.** Two units of reuse, nested:

- A **fragment** is a named run of events with parameters (`heal_at(town)`,
  `fly_and_walk(town, place)`, `buy(items, mart)`), expanded at load time like the place expansion
  above. It has no save of its own: if it fails halfway, the checkpoint around it runs again.
- A **checkpoint template** is a checkpoint with parameters (`stock(items)`, `get_one(item, spots)`,
  `duplicate(item, n)`, `candy_level(members)`): a start, a checked end, needs and provides, and its
  own save, so a run resumes there. Templates are built from fragments; a program is a chain of
  templates; a hand-written plan may use fragments directly.

Only checkpoints save and only events touch the game, so the runner, the logs and the watch page see
plain events, as now. Fragments and templates are data; OCaml generators only where a value is
computed (a shopping list, a round count).

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

## 5. Level-ups are decided before the run

Every program that levels a member (`candy_level`, `grind`, the Mail Glitch grind round) meets two
prompts it cannot leave to chance: an evolution scene, and "X is trying to learn Y" when four moves
are known. The answers are worked out before the run, never on the spot.

- The goal states the end state per member: the level, the species (evolve or not) and the moves
  it knows at the end.
- A generator reads the member's moves in-game at the start, steps through the levels with
  FireRed's learnsets, evolutions and the rule that an HM cannot be forgotten, and writes the
  `Level_up_policy` (#26) and the postconditions it predicts.
- The run is refused before it starts when a target move is never offered in that range, when the
  only move that could be replaced is an HM, or when the species cannot be reached by level-up.
- The learnset, evolution and HM data is extracted in PokemonSimulation, from pokefirered at the
  revision its `pret.json` already pins, and only read here. A hand-written policy is for tests.

The policy and every prompt's answer go into the run's log ("rattata: cancelled evolution",
"pidgeotto: declined gust"). Cancelling an evolution holds B before the scene starts, so it waits for
an evolution scene reader; until then a step that would evolve a member against its goal refuses.

## 6. Migration, one concern per PR

Each step runs on mGBA (3 passes from its start state) before console B, and leaves every existing
plan working. The structure comes first, so that other programs can be written in parallel on it.

1. **Rename `story` to `checkpoints`**, and the plan format from `pokesim-authored-checkpoint/1`
   to GamePilot's own name, with the old name still decoded. Moves only.
2. **Rename what deciding modules take to `game_steps`** (`rig`, `Battle_driver`, `Screen_driver`),
   with the naming rule in `AGENTS.md`. Renames only.
3. **Learnsets, evolutions and HMs** extracted in PokemonSimulation.
4. **Places and fragments.** The table, route targets that name a place, the expansion with the
   lift case. mg-01, mg-06, su-01 and tt-01 use them; a test checks that each expands to the same
   walks, rides and end poses as today's hand-written plan.
5. **Goals.** The typed decoder, `goal describe` and `goal check`, the goal in `run.json`. Then
   configurable Supplies (the checked item list, mart choice and generator, the Dept. Store 2F in the
   stock table; a test checks that the default goal generates today's su-01), and Team Training's goal
   generating its plans and its level-up policy.
6. **Checkpoint skip, alternatives and needs/provides** in `checkpoints`, and `pick_up_item`'s
   `no_item`. Tested with a scripted game. Then Team Training in three checkpoints as above, on mGBA
   from a save with the candy, one without it, and one where Route 6's candy is already gone.
7. **Readers from the mGBA level-up run**: the evolution scene, the move prompt in battle, the
   candy's "used on" screen, the faint screens.

Exceptions in library code become `Result`, one per PR, in between.

## Decisions (review, 2026-11-24)

1. **Plan format.** GamePilot owns it, renamed from `pokesim-authored-checkpoint/1` with the old
   name decoded as an alias. PokemonSimulation is the source of maps only.
2. **Goal to checkpoints.** A fixed chain with skips for now; each checkpoint records what it needs
   and provides. A planner that chains them comes much later. Checkpoints and small runs of steps
   must be reusable and composable (section 3).
3. **Unit of reuse.** Fragments inside checkpoint templates (section 3).
4. **Failed precondition.** Refuse before the first event, naming what is missing and which
   checkpoint provides it, with the same check on every backend. Chaining later, on the same
   needs and provides.
5. **Places.** GamePilot's table, pointing at PokemonSimulation's map objects (section 3).
6. **Configuration.** A goal file per run, one typed decoder per program, precise errors (section 1).
7. **Level-ups.** Decided before the run from the goal and FireRed's data (section 5).

The Fly badge is settled: a plan declares it in `metadata.preconditions` (`"badges": 8` or by
name, with `"hall_of_fame": true`), and the pre-flight reads it off the Trainer Card's front
(`Plan_preconditions`). Still open: mart choice (a fixed preference list, Celadon first, unless the
goal names a mart).
