# Composable rules: a game's rules from shared pieces (2026-11-25)

`Engine-Boundary.md` section 2 gives the engine one `GAME_RULES` per game family: a pose, actions
and postconditions, with three formats (plan codec, text, saved). The names below are the ones this
note settles (see "Names"): `Program_engine.Make (Rules) (Plan_format) (Event_snapshot)`. Today `Pokemon_rules` hard-wires
"grid + Pokémon" for every Pokémon game, and each game's own actions are raw JSON
(`Named_action of Raw.t`), read by the handler at run time. But a game's rules are three
independent choices:

| Game | Pose | Postconditions | Actions |
|---|---|---|---|
| FRLG | grid | Pokémon (party, items, coins, money, flags, moves, levels, marks) | story + grid + Pokémon + FRLG's own (fly, lift, ferry, mart, grind, the Mail Glitch steps: about 20) |
| BDSP | grid | Pokémon | story + grid + Pokémon + its own |
| PLZA | zone | none yet, Pokémon later | story + stick walk + Pokémon (later) + its own |
| SwSh | zone | Pokémon | story + stick walk + Pokémon + its own |
| Octopath 0 | zone | its own | story + its own walk + its own |

This note says how a game builds its rules from pieces, how each format composes the same way, and
the PRs that get there. Settled and not reopened: the rules are pure, and the plan format and the
event snapshot are each their own library used at one edge (#71, #81). Printing is no longer a
format: it moves into the rules (user, 2026-11-25).

## Names (user, 2026-11-25)

A game reads, at its one application of the engine:

```ocaml
(* today *)
include Engine_checkpoints.Make (Plza_rules) (Plza_plan_codec) (Plza_text) (Plza_saved)
(* after *)
include Program_engine.Make (Plza_rules) (Plza_plan_format) (Plza_event_snapshot)
```

| Today | After | What it is |
|---|---|---|
| `Engine_checkpoints.Make` | `Program_engine.Make` | the engine that runs a program's plans; a checkpoint is one unit of a plan, not the engine's name |
| `Pokemon_checkpoints`, `Plza_checkpoints` | `Frlg_engine`, `Plza_engine` | the engine applied to one game's rules |
| `*_rules` | `*_rules` | `GAME_RULES`: the pose, actions and promises, their checks, and now their printing |
| `*_text`, `Rules_text.TEXT` | gone | each part prints itself beside its type: `Pose.to_string`, `Pose.observed_to_string`, `Action.to_string`, `Postconditions.to_lines` |
| `*_plan_codec`, `PLAN_CODEC` | `*_plan_format`, `PLAN_FORMAT` | how a plan file writes the rules' poses, actions and promises |
| `*_saved`, `Event_states.SAVED` | `*_event_snapshot`, `Event_snapshot.SNAPSHOT` | what a run snapshots at the checkpoint's start (money, coins, items) and at each event's start (where the player was reckoned to stand), kept as `<n>-<event>.json` beside the event's save state so a run started from that state checks the same promises |
| `src/engine/checkpoints/{rules,plan,run,...,make}` | `src/engine/{rules,plan,run,...}`, `src/engine/program_engine` | one folder level less |

Inside the engine, `Plan`, `Runner`, `Failure`, `Game` and `Series` keep their names, and so do
`Plan.checkpoint` and the checkpoint runner: a checkpoint is still the stretch between two saves.

**Printing in the rules.** It is pure, so the rules stay free of JSON and I/O; a lint
`never_links` line per rules library still keeps out `yojson`. A piece is then three parts, not
four: its rules (with its printing), its plan format and its event snapshot. The `*_text` modules
of the pieces below fold into their rules modules, `Plan_text`, `Failure_text` and `Run_text` stay
in the engine and call `T.Pose.to_string` and the rest.

**A position read in the game is the pose's job.** `Pose.observed` is what the game reads and
`Pose.matches` compares it with the plan: map and tile in FRLG; in PLZA, after the tutorial, the
minimap's recorded name (`Plza_readers.Minimap`), so the engine checks PLZA's start and end the way
it checks FRLG's. PLZA's `Start_signature` (#100) keeps the rest of its checks (talk prompt, wild
zone, party count) until they become preconditions.

## The shape

A piece is a pose, an action set or a set of promises, and brings up to three parts: its rules
type with its printing, its plan format and its event snapshot. A game's rules are written by hand from
pieces, in a dozen lines:

```ocaml
(* games/frlg/checkpoints/rules/lib/frlg_rules.ml *)
module Pose = Grid_pose                 (* map, tiles, facing; read as map and tile *)

module Action = struct
  type t =
    | Story of Story_action.t           (* talk, answer, scene, save: the engine's *)
    | Grid of Grid_action.t             (* route, ready, legs, step *)
    | Pokemon of Pokemon_action.t       (* new_game, options, battle, train, heal, shop *)
    | Frlg of Frlg_action.t             (* fly, lift_floor, ferry, mart, grind, capture, ... *)
end

module Postconditions = Promises.With_position (Grid_pose) (Pokemon_promises)

let ends_at : Action.t -> Pose.t option = function
  | Grid a -> Grid_action.ends_at a     (* a route's or ready's target *)
  | Story _ | Pokemon _ | Frlg _ -> None

let position (p : Postconditions.t) = p.position
```

`GAME_RULES` gains the two functions at the bottom, so the engine can work out a checkpoint's
declared end without knowing grids (see "Shared code" below):

```ocaml
module type GAME_RULES = sig
  module Pose : POSE
  module Action : ACTION
  module Postconditions : POSTCONDITIONS
  val ends_at : Action.t -> Pose.t option              (* where an action says it leaves the player *)
  val position : Postconditions.t -> Pose.t option     (* a promised end position *)
end
```

## Actions: a variant per game, decoded from a list of parts

The action sum is a plain variant the game writes, one constructor per set. Matches read
`Grid (Route r)` and `Pokemon (Battle b)`; a set left out of a match is the compiler's
exhaustiveness error, naming the constructor. Only decoding needs help, because it goes from a name
to a constructor. Each set's decoder says which kind names it owns, and the game lists its parts
once, each with its constructor:

```ocaml
(* engine/checkpoints/plan_codec: Action_parts *)
module type ACTION_DECODE = sig
  type t
  val names : string list                    (* the kinds it owns, as plans write them *)
  val of_plan : string -> (where:string -> Json_field.obj -> (t, string) result) option
end

type 'action part = Part : (module ACTION_DECODE with type t = 'a) * ('a -> 'action) -> 'action part

val action_of_plan :
  'action part list -> string -> (where:string -> Json_field.obj -> ('action, string) result) option
val claimed_twice : 'action part list -> string list   (* names two parts own; a test wants [] *)

(* games/frlg/checkpoints/plan_codec/lib/frlg_plan_codec.ml *)
let parts = Action_parts.[
  Part ((module Story_action_decode), fun a -> Story a);
  Part ((module Grid_action_decode), fun a -> Grid a);
  Part ((module Pokemon_action_decode), fun a -> Pokemon a);
  Part ((module Frlg_action_decode), fun a -> Frlg a) ]
let action_of_plan = Action_parts.action_of_plan parts
```

Text goes the other way, from the constructor to the set, so it is a match, again checked for
exhaustiveness:

```ocaml
let action = function
  | Story a -> Story_action_text.action a   | Grid a -> Grid_action_text.action a
  | Pokemon a -> Pokemon_action_text.action a | Frlg a -> Frlg_action_text.action a
```

**Why not `Sum2`/`Sum3` functors.** A functor sum has generic constructors (`First`, `Second`,
`Third`, or nested `Left (Right x)`), needs a functor per arity and a parallel one for each format
(`Sum3_decode`, `Sum3_text`, each pinned by `with type`), and its type errors print
`Sum3(Story_action)(Grid_action)(Pokemon_action).t` against `Frlg_rules.Action.t`. **Why not
polymorphic variants** (`type t = [ Grid_action.t | Pokemon_action.t ]`): flat matches are nice,
but errors are long, every set needs `:>` coercions, and two sets with the same tag and args merge
silently, which is exactly the overlap we want to catch. The hand-written variant costs four lines
per game and reads plainly in errors: `Grid_action.t -> Frlg_action.t` is not
`Grid_action.t -> Frlg_rules.Action.t`.

**Overlapping names.** Kind names are strings, so the compiler cannot see a clash. Each game's
codec test asserts `claimed_twice parts = []`, and the engine's toy test shows the check failing on
two toy sets that both own `rest`. Were a clash to slip through, `action_of_plan` takes the first
part that owns the name. A game takes a set whole; when it needs only part of one, the set is
split. A game that runs a shared action differently (PLZA's real-time battle) keeps the shared
type and gives its own runner (see "Running"). Only a different argument shape needs a new name,
in the game's own set.

**The engine's kinds become a set.** `Talk`, `Answer`, `Scene` and `Save` move out of `Plan.kind`
into `Story_action`, the engine's piece with its decoder and text. Nothing in the runner treats
them specially today; they are only dispatched to `run_builtin`. After the move, `Plan.event.kind`
is `T.Action.t`, `Game.t` has one `run : Plan.event -> T.Action.t -> outcome` in place of
`run_own`, `run_builtin` and `game_actions`, and every game's sum lists `Story`. The engine keeps
no kind of its own, so a game whose talk differs (a game with no yes/no prompt) can still use the
set, or leave it out and write its own.

`Named_action` and `Raw` leave the actions (`Raw` stays for `execution` and `metadata`).
Typing FRLG's actions moves their errors from run time to plan load. The command steps the
pre-flight and make-room show on the watch page as generated plans (`Shadow_plan`) are not game
actions; they become `Command_step of string`, an engine set with no args, run through the step
table the command hands `Checkpoint_run`, as its `?actions` does today.

## Postconditions: a position and the family's promises

The product is `With_position`: an end position in the game's pose, plus one set of the family's
promises. The record is the engine's, so the codec and text can build the same type without a
functor path between them:

```ocaml
(* engine/checkpoints/rules: Promises *)
type ('pose, 'promises) with_position = { position : 'pose option; promises : 'promises }

module With_position (P : POSE) (R : POSTCONDITIONS) : POSTCONDITIONS
  with type t = (P.t, R.t) with_position and type reads = R.reads
  (* check is R's: the position is the runner's end check, as today *)
```

The decoder owns `position` and reads it with the pose's decoder; the promises' decoder lists its
keys (`keys : string list`) and reads only those; the pair checks unknown fields against both. The
text is `position <pose>` and then the promises' lines, as today.

Coins stay in `Pokemon_promises`. Split out, they would move: results, text lines and decode
errors put coins between items and money today, and a product puts its parts end to end. Keeping
them costs nothing either: a Pokémon game without a Game Corner never promises coins. So a general
`Pair` of two promise sets waits for the game that needs one, and would compose the same way (keys
claimed, unknown fields checked once, parts in order).

## The formats

| Piece | Lives in | Rules, with its printing | Plan format | Event snapshot |
|---|---|---|---|---|
| `Story_action` | engine | talk, answer, scene, save | `Story_action_decode` | |
| `Command_step` | engine | a command's step, by name | yes | |
| `Zone_pose` | engine | place, spot | `Zone_pose_decode` | `Zone_snapshot` |
| `With_position` | engine | position + promises | `With_position_decode` | |
| `Grid_pose` | `src/pokemon/navigation/grid/checkpoints` | map, tiles, facing; observed | `Grid_pose_decode` | `Grid_snapshot` |
| `Grid_action` | same | route, ready, legs, step | `Grid_action_decode` | |
| `Pokemon_action` | `src/pokemon/checkpoints` | new_game, options, battle, train, heal, shop | `Pokemon_action_decode` | |
| `Pokemon_promises` | same | party ... marks, `Postcondition_check` | `Postcondition_decode`, `Party_decode` | `Pokemon_start_snapshot` |
| `Frlg_action` | `src/games/frlg/checkpoints` | today's `Action_requests` and the rest | `Frlg_action_decode` | |

Today's `*_text` modules (`Story_action_text`, `Zone_pose_text`, `With_position_text`,
`Grid_pose_text`, `Pokemon_action_text`, `Postconditions_text`, `Frlg_action_text`) fold into the
piece's rules module as its `to_string`.

Each column is its own library, as today, so a lint `never_links` line per rules library keeps it
free of JSON and text. How each format composes:

- **Plan format.** `pose_of_plan` is the pose piece's; `action_of_plan` is `Action_parts` over the
  game's list; `postconditions_of_plan` is `With_position_decode (Pose_decode) (Promises_decode)`.
- **Printing.** The pose piece's `to_string` and `observed_to_string`; the game's `Action.to_string`
  matches its sum and calls each set's; `With_position.to_lines`.
- **Event snapshot.** What a run keeps is the promises' start reads and the pose's observed position. The
  engine gives `Kept.Make (Start) (At)`, where `Start` writes its fields in order and `At` is the
  observed pose's derived JSON:

```ocaml
(* engine/checkpoints/saved: Kept *)
type ('start, 'at) kept = { start : 'start; at : 'at option }
module type FIELDS = sig
  type t
  val fields : t -> (string * Yojson.Safe.t) list            (* in file order *)
  val of_fields : (string * Yojson.Safe.t) list -> (t, string) result   (* a missing key: unread *)
end
module Make (Start : FIELDS) (At : sig type t [@@deriving yojson] end) :
  Event_states.SAVED with type t = (Start.t, At.t) kept
  (* the file is Start's fields, then "at" *)
```

**Byte-identical.** `Pokemon_start_snapshot` keeps today's derived record, so FRLG's file stays
`start_money`, `start_coins`, `start_items`, `at`, nulls included, and older files with fewer
fields still load. PLZA's (#89) is `Make (No_start) (Zone_snapshot)`: `{"at": ...}`, as now. A golden
of a kept file's bytes goes in before anything moves. `plans.golden` stays byte-identical through
every PR, with one exception: the PR that types FRLG's actions changes their 96 event lines and
the 28 outline lines that count them, because the typed value prints its own text (`mart
CeladonCity_DepartmentStore_4F: 2 retro-mail`), not its JSON args. That PR's golden diff touches
those lines only. The plan rewrite after it is again byte-identical, which proves the rewrite
faithful. The order inside a line or a promise list never changes: each set's text starts with its
kind name, as `Plan_text`'s counts need, and promises keep position first, then the family's.

## Arguments that need a table: mart, fly, grind

**Recommendation.** A typed action keeps the names the plan writes (a mart's map, a Fly town, a
grind strategy) and does not look them up while decoding. FRLG's plan loader checks every name
against its table once, when it loads the plan, and fails naming the event; the run looks the name
up again when it gets there.

**Why it comes up.** Typing FRLG's actions moves the reading of their args from run time to plan
decoding, and decoding is pure: it cannot read a file. Today three of these args are checked by
reading something:

| Action | Its args name | Checked today against |
|---|---|---|
| `mart` | a mart map and items | the stock table, `kanto_mart_stocks.json` |
| `fly` | a town, and the flyer by species | `Fly_towns`; the species becomes a slot from the reckoned party |
| `grind` | a strategy | the grind strategies file |

**What it looks like.** The typed values hold names: `Mart { map; lines; budget }` (`Mart_plan.t`
already is that), `Fly { town; flyer : Action_args.member; menu_row }`, `Grind { strategy :
string; ... }`. `Plan_file.load`, which reads files already, checks them and fails as
`01-celadon-setup.plan.json: checkpoint.events[8]: no Mart on CeladonCity_4F`. The flyer stays a
party member, not a slot, until the run, because the party is only known then; `use_item`'s member
works the same way.

**Rejected.**

- A plan format built over the loaded tables: the engine would be applied per run, not once.
- A `context` argument on `PLAN_FORMAT`: every game would carry FRLG's tables.
- OCaml generated from the tables at build time: a generator per table, and the tables would stop
  being data read through `Repo_files`.

## Running stays per game

The action types are shared data: FRLG and PLZA both have `Pokemon (Battle b)`. How an action runs
is each game's own, through its `game_steps`: FRLG fights a battle through turn-based menus, PLZA
in real time. So each game writes one function that takes an event's action and runs it, a match
over its sum that hands each case to the game's code for it:

```ocaml
(* FRLG: the engine calls this for each event; [game] is the running game (session, readers, log) *)
let run_action game event = function
  | Story a -> Frlg_story.run game a                     (* talk, answer, scene, save *)
  | Grid a -> Frlg_walk.run game a                      (* planned on the grid, walked *)
  | Pokemon (Battle b) -> Frlg_battle.run game b        (* turn-based menus *)
  | Pokemon a -> Frlg_pokemon_actions.run game a        (* the other Pokémon actions: heal, shop, train, new_game *)
  | Frlg a -> Frlg_game_actions.perform game event a    (* FRLG's own: fly, mart, grind, the Mail Glitch steps *)

(* PLZA, once it battles: the same action type, its own way to run it *)
  | Pokemon (Battle b) -> Plza_battle.run game b        (* real time *)
```

## Per-game instances and shared code

`Pokemon_checkpoints` cannot stay family-wide: its plan type carries the action sum, which is now
per game. FRLG gets `Frlg_engine = Program_engine.Make (Frlg_rules) (Frlg_plan_format)
(Frlg_event_snapshot)`, as PLZA gets `Plza_engine`. The 140 files that name `Pokemon_checkpoints`
(113 under `games/`) are renamed in one sed PR; those that use only `Failure.cause`, which does not
depend on the rules, point at `Engine_run.Failure` instead, so fewer files carry a game's instance.
`Frlg_engine` is a free name, so today's `frlg_checkpoints` library (FireRed's checkpoint runs:
`Checkpoint_run`, `Plan_file`, `Plan_needs`, `Preflight`) keeps its name.

Shared code goes one of two ways:

- **Code over a whole plan or failure** becomes a functor over `GAME_RULES` and moves to the
  engine. `Checkpoint_end.Make (T)`: the next start, else the last event's `declared_after`, else
  `T.ends_at` of its action, with `T.position` preferred when promised. `Console_runs.Make (T)`: it
  only reads `Failure.reason`. Both are agnostic once `ends_at` exists.
- **Code over a Pokémon part** takes that part's type directly (`Pokemon_promises.reads`,
  `Pokemon_action.t`, `Grid_pose.observed`), never the game's sum, so it needs no functor.
  `Room_policy` already does; FRLG's `Postcondition_reads` and a shared battle runner would too.

FRLG's `Plan_needs` and `Party_room` change for the better: they match `Frlg (Mart m)` and
`Frlg (Ingame_trade t)`, not `Named_action` and a lookup of JSON keys.

## Where the pieces live

```
src/engine/
  rules/          + Story_action, Command_step, Zone_pose, Promises (With_position), each printing itself
  plan_format/    + Action_parts, Story_action_decode, Zone_pose_decode, With_position_decode
  text/           Plan_text, Failure_text, Run_text only
  event_snapshot/ + Kept, Zone_snapshot
  run/            + Checkpoint_end;  series/ + Console_runs
  program_engine/ Program_engine.Make
src/pokemon/navigation/grid/checkpoints/{rules,plan_format,event_snapshot}/
                  Grid_pose, Grid_action and their formats, beside the grid they walk
src/pokemon/checkpoints/{rules,plan_format,event_snapshot}/
                  Pokemon_action, Pokemon_promises and their formats; no instance
src/games/frlg/checkpoints/{rules,plan_format,event_snapshot,engine}/
                  Frlg_action, Frlg_rules and formats, Frlg_engine; frlg_checkpoints as today
src/games/pokemon/plza/checkpoints/{rules,plan_format,event_snapshot,engine}/
                  as #89, built from pieces, Plza_engine
```

The stick walk stays PLZA's own action until SwSh needs it, then moves to
`src/pokemon/navigation/stick` (or the engine, if Octopath 0 walks the same way).

## Fit

- **PLZA (#89).** `Pose = Zone_pose`; `Action = Story | Plza of Plza_action.t` (walk,
  wait_for_platform, set_text_speed_fast, plus_skip, today three of them `game_action`s);
  `Postconditions = With_position (Zone_pose) (No_promises)`. It links the engine only. When its
  first battle comes it joins `family pokemon` and adds `Pokemon of Pokemon_action.t` and
  `Pokemon_promises`, with no change to FRLG.
- **SwSh** is PLZA's shape with Pokémon promises from the start. **BDSP** is FRLG's shape with
  its own set.
- **Octopath 0** (Engine-Boundary 3d): `Zone_pose`, `Story | Octopath of Octopath0_action.t`
  (walk, beg, rest_at_inn, battle_round, shop, equip), `With_position (Zone_pose)
  (Octopath0_promises)` (levels, equipped). No Pokémon or grid code.
- **The toy game** is rebuilt from pieces: `Zone_pose`, `Story`, two toy sets (`Toy_walk`: walk;
  `Toy_inn`: rest, buy), `With_position (Zone_pose) (Toy_promises)`, `Kept.Make`. Its tests show
  the sum decoding and printing, the overlap check failing on a third set that also owns `rest`,
  a zone position promised and checked, and a kept file read back.

## Leftover names

- "Action" for the value, everywhere in OCaml: `kind_of_plan` becomes `action_of_plan`, `TEXT.kind`
  becomes `action`, `Kind_decode` and `Kind_text` become `Pokemon_action_decode` and
  `Pokemon_action_text`. The event field stays `kind` (now of type `T.Action.t`): it mirrors the
  plan's `"kind"`, and the plan's `"action"` is already the event's `way`.
- Sets are `*_action` (singular, a module named for its `t`, as `Pokemon_action` is), not
  `*_moves`: a Pokémon's moves are already promises (`knows`).
- "Own kind" goes: the toy test's cases say "the toy's walk action", `plan.mli` says "the engine's
  story actions", Engine-Boundary's rename note keeps the history.
- `Leg.action` in `src/pokemon/navigation/grid/planning/lib/leg.mli` ("a step of a game's own
  kind": starting to Surf, opening a gate) is a planner step, not a plan action. It becomes
  `Leg.special_step`, its constructor `Special_step`, its doc "a step that is more than a press".

## Migration

Every PR keeps every plan, test and run as it is; **S** marks a structural one.

| # | PR | S | After |
|---|---|---|---|
| 0 | Names (above): `Program_engine`, `*_plan_format`, `*_event_snapshot`, the folder level, `Pokemon_checkpoints` to `Pokemon_engine` until step 8 splits it. Renames only | S | |
| 0b | Printing into the rules: each `*_text` piece folds into its rules module, `TEXT` deleted, `Program_engine.Make` takes three arguments. `plans.golden` byte-identical | S | 0 |
| 1 | Leftover names (above). Renames only | S | |
| 2 | Goldens for what must not move: a kept file's bytes, the plan decode errors. Tests only | | |
| 3 | Engine pieces: `Action_parts`, `Story_action`, `Command_step`, `Zone_pose`, `With_position`, `Kept`; `ends_at` and `position` in `GAME_RULES` (Pokémon gives today's); the toy game rebuilt from pieces | S | 1 |
| 4 | Built-ins out of the plan: Talk..Save become `Story` in Pokémon's sum, `Game.t` loses `run_builtin`; `Named_action` stays | S | 3 |
| 5 | Grid pieces under `navigation/grid/checkpoints`; `Pokemon_action` keeps the rest; zones leave Pokémon's pose; Pokémon's promises become `With_position (Grid_pose) (Pokemon_promises)`, its saved `Kept.Make` | S | 2, 4 |
| 6 | `Checkpoint_end` and `Console_runs` to the engine as functors over `GAME_RULES` | S | 5 |
| 7 | (dropped: `Frlg_engine` needs no library moved) | | |
| 8 | `Frlg_rules` (Story, Grid, Pokemon), its formats and `Frlg_engine`; `Pokemon_engine` deleted; the 140 files renamed | S | 6 |
| 9 | FRLG's actions typed, in three PRs: the shared ones (`Action_requests`); travel (fly, lift_floor, ferry); battles and the Mail Glitch (grind, capture, berry PP, double battle, mail, candy). Load check of marts, towns, strategies; `Plan_needs` and `Party_room` on typed actions. `game_action` with `"action": "mart"` is read as kind `mart`; unclaimed names stay `Named_action` until the last | S (format) | 8 |
| 10 | Plans rewritten by script to `"kind": "mart"`; shadow plans to `Command_step`; `Named_action`, the alias and `game_actions` deleted. Golden identical | S (format) | 9 |
| 11 | PLZA from pieces, after #89 merges | S | 4 |
| 12 | PLZA in `family pokemon` with its first battle | S | 5, 11 |
| 13 | Octopath 0's rules from pieces (Engine-Boundary PR 9) | S | 3 |

0, 1 and 2 can start at once; 0b follows 0. FRLG's line (3 to 10) runs first; 11 waits for it only where it needs
4, and Octopath 0 needs only the engine pieces.

## Decisions (user approved all as recommended, 2026-11-25)

1. **The action sum is a variant each game writes** (`Story | Grid | Pokemon | Frlg`, matched as
   `Grid (Route r)`), decoded through a list of parts, not `Sum2`/`Sum3` functors or polymorphic
   variants. Recommended: yes.
2. **Coins stay in `Pokemon_promises`**, and the only product is `With_position`; a general `Pair`
   waits for a game with two promise sets. Recommended: yes, since splitting coins moves them in
   the results, the text and the errors.
3. **One golden diff.** Typing FRLG's actions changes their 96 event lines and 28 outline lines in
   `plans.golden` to the typed action's text. Recommended: accept it, in that PR only. The
   alternative keeps the raw args beside the typed value to print them, which puts JSON back into
   the rules.
4. **Plan format.** Rewrite `{"kind": "game_action", "action": "mart"}` to `{"kind": "mart"}` in
   every plan and drop `game_action`. Recommended: yes, as its own PR after the typing, its
   golden byte-identical.
5. **Names: decided** (user, 2026-11-25; see "Names"). `Program_engine.Make (Rules) (Plan_format)
   (Event_snapshot)`, instances `*_engine`, printing in the rules, PLZA's minimap as its observed
   pose.
6. **Table references are names checked at plan load** (marts, Fly towns, grind strategies), and
   looked up again at run time. Recommended: yes, over a codec context or tables generated at build
   time.
7. **Names.** The event field stays `kind` (of type `T.Action.t`), sets are `*_action`, and the
   engine's set is `Story_action`. Recommended: yes.
