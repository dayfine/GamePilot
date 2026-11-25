# Engine boundary: the checkpoint engine apart from Pokémon (draft, 2026-11-24)

GamePilot's checkpoint engine (program, goal, checkpoints, plan, event, inputs: `Programs-As-Goals.md`)
lives under `src/pokemon/checkpoints`, and much of it is Pokémon- or grid-specific. A second game,
not a Pokémon one and without a tile grid, is coming soon: Octopath Traveler 0 on the Switch. This
note says what is game-agnostic today, what moves where, how a game plugs in its own parts, and the
few new concepts the first two Octopath programs need. It is for review before any code; every move
is its own PR later, and nothing here is ported ahead of a program that needs it.

Settled and not reopened here: the levels from program down to inputs, and only checkpoints save;
needs and provides refuse before the first event; typed goal files; the places table and fragments
expanded at load; plans stay linear (`skip_if` only), and branching goes in a deciding OCaml module
with a `game_steps` record, as Pokémon battles do.

## The two programs that drive it

1. **Beg for an item.** Save next to an NPC; use the Beg path action (3-5% success); read the
   result; on failure reload the in-game save and try again until the item is in the inventory.
   Open: whether a reload rerolls the game's RNG, or the attempt must vary something (a wait, a
   step) first.
2. **Farm a rare cat enemy.** A prep checkpoint (buy items, equip gear and skills; provides
   `cat-kit`), then a farm checkpoint (needs `cat-kit`; `repeat_until` a goal such as level 60; each
   round walks the zone, battles, and decides: a cat gets the reliable kill sequence, anything else
   is fled), then a rest at an inn (a fragment like `heal_at`).

Both are linear plans. What they need that the engine lacks: an attempt that fails by luck kept
apart from one that fails by fault (program 1), a start that is an in-game save slot rather than an
emulator state (both: there is no emulator for this game), and walks without tiles (program 2).

## 1. Inventory

**A** game-agnostic as it is; **G** tied to the tile grid; **P** tied to Pokémon; **mixed** says
which part is which. `Grid_maps` is `src/pokemon/navigation/grid/maps`.

### `pokemon/checkpoints/plan` (`checkpoints_plan`)

| File | | What ties it |
|---|---|---|
| `plan.mli` | mixed | A: `event` (id, action, why, `skip_if`, `once_per_save`), `checkpoint`, `t` (game, execution, metadata, retries, repeat), `count`, `money`, `Talk`, `Answer`, `Scene`, `Save`, `Game_action`. G: `leg`, `route`, `Route`, `Ready`, `Legs`, `Step` (`Grid_maps.Direction`). P: `party`, `slot`, `knows`, `level`, `marks`, `coins`, and the built-ins `Battle`, `Train`, `Heal`, `Shop`, `New_game`, `Options` as FireRed runs them |
| `pose.ml` | mixed | G: `grid` (map, tiles, facing), `observed` (map, tile), `matches`. A: `zone` (place, spot, heading), already decoded and never used |
| `plan_decode.ml` | mixed | A: format names, strictness, unique ids, the event loop. G and P: the kind table and its args, grid poses |
| `plan_fields.ml` | mixed | A: field readers. G: `grid_pose`; P: `item` |
| `postcondition_decode.ml` | mixed | A: `items`, `money`, `flags`. P: `party`, `coins`, `knows`, `levels`, `marks`. G: `position` |
| `party_decode.ml` | P | the party a checkpoint promises |

Every file reads JSON through `Grid_maps.Json_field`, a game-agnostic reader that sits in the grid
library only because the map decoders came first.

### `pokemon/checkpoints/expand` (`checkpoints_expand`)

| File | | What ties it |
|---|---|---|
| `plan_json.ml`, `table_decode.ml` | A | raw plan JSON and table field reads, as `Result` |
| `fragment_table.ml`, `fragment_calls.ml` | A | fragments and their calls; the game resolves `{town.nurse}` |
| `place_routes.ml` | G | `spot` is map, tile, facing; rides are lifts between floors; the position is reckoned from one-tile targets |

### `pokemon/checkpoints/run` (`checkpoints_run`)

| File | | What ties it |
|---|---|---|
| `game.mli` | mixed | A: the record of handlers, `game_actions`, `flag_holds`, `save`, `reload`, `log`. G: `walk_route` takes `Plan.route`, `position` returns a grid `Pose.observed`. P: `heal` between rounds |
| `runner.ml` | mixed | A: order, skips, logging, handler check, end state. G: `declared_after` and `end_at` checked only as grid poses (a zone is silently not checked) |
| `checkpoint_end.ml` | G | the end is a grid pose from the next start or the last route |
| `failure.ml` | mixed | A: `cause`, `Handler`, `No_handler`, `Unmet_postconditions`. G: `Not_at_declared`, `Not_at_end` carry grid poses |
| `postcondition_check.ml` | mixed | A: `verdict`, `result`, `unmet`, `log_lines`, the count and money comparisons against the start. P: `observed` and `start` fields (party, coins, knows, levels, marks) |
| `checkpoint_trials.ml` | A | runs, passes, the hard stop, attempts. But an attempt lost to luck and one lost to a fault are the same `Attempt_failed` |
| `event_range.ml`, `event_progress.ml` | A | partial runs need a backend that keeps states (mGBA) |
| `event_states.ml` | mixed | A: tracker. Emulator-bound: `.ss` files. P and G: `kept` holds Pokémon start reads and a grid position |
| `repeat_until.ml` | mixed | A: the loop. P: the `Heal` chore; raises `Invalid_argument` (waived) |
| `room_policy.ml` | P | party room and the PC |

### `pokemon/checkpoints/series` and `plan_text`

| File | | What ties it |
|---|---|---|
| `chain_progress.ml`, `checkpoint_order.ml`, `round_trials.ml` | A | |
| `console_runs.ml` | A | the decision is agnostic (its doc says "soft reset"); the steps are bound to FireRed in `bin/console_session.ml` |
| `plan_text.ml` | mixed | A: `event`, `outline`, `count_text`. G and P: kinds, poses, postconditions as text |

### `core` and around it

| Library | | What ties it |
|---|---|---|
| `effects`, `session`, `live`, `replay`, `run_record`, `watch_report` | A | |
| `screen_state` | A | facts (fade, banner, dialog, battle, free control, stillness) and the settle rules are shared by every game; the timings were measured on FireRed and a game may give its own `rule` |
| `switch_home` | mixed | A: parking and resuming on HOME. Tied to the GBA picture: boxes clipped to FireRed's `GAME_BOX` viewport, tests on FireRed's tile |
| `games/frlg/repo_files` | A | `Repo_files.locate`, `Json_file`: agnostic, but under FireRed, and `program_registry` depends on it |
| `bin/` | mixed | 13 files name `Frlg_*`: plan loading, the live checkpoint, console save steps, pre-flight, make-room, guides |
| `dev/lint/ocaml_lint.conf` | mixed | layer `game` may use `pokemon`: nothing stops a non-Pokémon game from using Pokémon code |
| `daemon/src/viewport.h` | G | only `nso_gba_viewport` (240 x 160 inside the Switch frame); a native Switch game is the whole 1920 x 1080 frame |
| `Wire.command` | A | buttons and waits; no analog stick, no ZL/ZR |

In short: the skeleton (run order, skips, trials, rounds, chains, fragments, the watch page, the
records) is agnostic already. The grid and Pokémon parts are three types (where the player is, the
game's own event kinds, what a checkpoint promises) and the code that reads, prints and checks them.

## 2. Layout

```
src/base/json_field/         Json_field, moved from Grid_maps (and [catch]: a reader's failure as a Result);
                             its grid readers stay as Grid_maps.Grid_field
src/base/repo_io/            library repo_io: Repo_files, Json_file, moved from games/frlg
src/engine/checkpoints/
  terms/                     GAME_TERMS: the signature a game fills (below)
  postcondition/             Postcondition (result, verdict, log_lines), Count, Money (from the plan and Postcondition_check)
  plan/                      Make: Plan, Plan_decode, Plan_text; Plan_fields, the field readers they share
  run/                       Make: Game, Runner, Failure, Repeat_until;
                             Event_states, Checkpoint_trials, Event_range, Event_progress, Roll (new)
  series/                    Chain_progress, Checkpoint_order, Round_trials, Console_start (new)
  expand/                    Plan_json, Table_decode, Fragment_table, Fragment_calls
  make/                      Engine_checkpoints.Make: every functor above over one game's terms;
                             its tests apply it to a toy game with zones and no grid
src/pokemon/checkpoints/
  terms/                     Pokemon_terms: Pose (grid), Kind, Postconditions, Saved; Own_kind,
                             Postcondition_check and the decoders behind them
  instance/                  Pokemon_checkpoints = Engine_checkpoints.Make (Pokemon_terms)
  checkpoint_end/            Checkpoint_end (the grid end check's pose)
  room_policy/               Room_policy
  series/                    Console_runs, until Console_start (section 3b) moves it to the engine
  expand/                    Place_routes (grid, lifts)
src/games/frlg/              unchanged, but opens Pokemon_checkpoints
src/games/octopath0/         section 3d
```

Dependencies stay one-way: `base <- core <- engine <- pokemon <- games/<pokemon game>`, and
`base <- core <- engine <- games/octopath0`. The lint gets an `engine` layer and game families:
`allow engine engine core base`, `allow pokemon pokemon engine core base`, and a game may use
`pokemon` only when it is listed as a Pokémon game (`family pokemon game frlg`: the family, the path variable naming the game, then its members), so `octopath0` cannot.

### How a game plugs in

The engine needs four small modules from a game, each holding its own type
(`src/engine/checkpoints/terms/lib/engine_terms.mli`, as shipped):

```ocaml
module type GAME_TERMS = sig
  module Pose : sig
    type t           (* where a plan says the player stands: a grid pose, a zone *)
    type observed    (* where the game reads the player *)
    val decode : where:string -> Json_field.obj -> (t, string) result
    val matches : t -> observed -> bool
    val text : t -> string
    val observed_text : observed -> string
  end
  module Kind : sig
    type t           (* the game's own events: route, battle, heal; walk, rest *)
    val decode : string -> (where:string -> Json_field.obj -> (t, string) result) option
        (* the decoder of a kind name, [None] when the name is not this game's *)
    val text : t -> string
  end
  module Postconditions : sig
    type t           (* what a checkpoint promises: metadata.postconditions, a repeat's until *)
    type reads       (* what the game read for them, start reads included *)
    val decode : where:string -> Json_field.obj -> (t, string) result
    val check : t -> reads -> Engine_postcondition.Postcondition.result list
    val text : t -> string list
  end
  module Saved : sig
    type t           (* kept beside an event state: the start reads and where the player stood *)
    val to_json : t -> Yojson.Safe.t
    val of_json : Yojson.Safe.t -> (t, string) result
  end
end
```

(The file names each part as its own module type, `POSE`, `KIND`, `POSTCONDITIONS` and `SAVED`, so a
game's `.mli` can extend its own module with one: Pokémon's `Pose` is its grid `Pose` plus the
engine's four values, and its `Postconditions` is its record plus `decode` and `check`.)

`check` takes the reads alone: what the game read at the start is part of `reads`, so it has no
`~start`. The game reads its postconditions through a function the caller hands the runner with
them (`Runner.run ?end_state:(postconditions, read)`, FireRed's `Postcondition_reads`), not through
a field of `Game.t`; the engine only orders the check and logs it. A plan holds its postconditions
as `Postconditions.t option`, `None` when it states none, and the runner reads and checks the end
state only when it is given one. Pokémon reads at the end only a party, items, coins, money or
flags (`Postconditions.at_end`); a plan whose postconditions name only a position, moves, levels or
marks still decodes them, because the end tile, the grind cap and the pre-flight use them. The
texts are there because the engine prints plans (`Plan_text`); `Saved` is what `Event_states` keeps
beside each state, one JSON object per event as before.

The engine owns no promise fields: items, money and flags are the game's like the rest. A plan's
`postconditions` is one object, decoded once with its known fields checked, and Pokémon logs its
results in one order that interleaves those three with the rest (party, items, coins, money, flags,
moves, levels, marks, as `Postcondition_check` ports it). Split between the engine and the game, the
object would need two decoders sharing one field list, and the log order would change. Not every game has money or a bag either (the toy game's promises are gold
and flags). What the engine gives instead are the parts: `Postcondition` (result, verdict, log lines),
`Count` and `Money` (a value, floor, range or change from the start, and their checks and texts),
which `postcondition/` holds rather than `plan/` because they are checks as much as plan types.

`Engine_checkpoints.Make (T)` gives `Plan`, `Plan_decode`, `Plan_text`, `Failure`, `Game`, `Runner`
and `Repeat_until` over `T`'s types, and `Event_states`, which needs none of them; the engine's own kinds are `Talk`, `Answer`,
`Scene`, `Save`, `Game_action` and `Own of T.Kind.t`. The plan format does not change: a kind name
the engine does not know goes to `T.Kind.decode`. Pokémon applies it once (`Pokemon_checkpoints`), and
the engine's tests apply it to a toy game with zone poses and no grid, which is what proves the
boundary. `Plan_text` moved into the engine with the plan: the game's part of it is its terms' texts.
The handlers stay a record (`Game.t`): `run_own : Plan.event -> T.Kind.t -> outcome` takes the
game's own kinds, and `run_builtin : Plan.event -> outcome` stays beside it for the engine's kinds
the game still carries out (`talk`, `answer`, `scene`, `save`: the engine names them, the game
presses the buttons). `heal` becomes `between_rounds`.

Two modules came out differently from the first draft. `Checkpoint_end` stays in
Pokémon: the declared end is a grid pose taken from the next start, the last route or ready target,
or a `position` promise, all Pokémon terms; the runner takes the result as `?end_at:T.Pose.t`.
`Event_range` takes the checkpoint's event ids rather than its events, so it needs no functor and
stays a plain module in `run/`.

The pieces are already the repo's patterns: a record of what the game does (`Game.t`, the
`game_steps` of deciding modules), data tables for places and fragments, decoders that return
`Result`. The question is only how the engine's types get the game's.

| | Functor over `GAME_TERMS` (recommended) | Type parameters | Extensible variants |
|---|---|---|---|
| Shape | `Make (T)` once per game family | `('pose, 'kind, 'promises) Plan.t`, and so on | `type own_kind += Route of ...`, decoders registered by name |
| Engine signatures | plain (`Plan.event`) inside the functor | two or three type variables in every signature that names a plan, failure or game | plain |
| Game code | concrete types, exhaustive matches | concrete, but annotations everywhere | a catch-all case in every match; a kind can be missed |
| Wiring | one application per family | none | registration at start-up, against the registry's "a plain list" rule |
| Cost | functor `.mli`s and error messages are heavier to read; one large move PR | many small signature edits, noisy for every reader forever | least churn now, weakest checking later |

The functor wins because the game's types appear in a dozen engine modules but are chosen once per
game: one application keeps the engine's signatures readable and the game's matches exhaustive.
Type parameters are the fallback if the functor's `.mli`s prove too hard to read; extensible variants
are not proposed. Keeping the game's parts as raw JSON (as `Game_action` args are) is the fourth
option, rejected: errors would show at run time, not when the plan loads.

`bin/` picks a game by the registry's `game_id` and calls that game's command module, a first-class
module of one signature (`Game_commands.S`: load plans, build `Game.t`, the console start of section
3b, the pre-flight). FireRed's is today's code moved out of `bin/`.

## 3. New engine concepts

### a. A roll: expected failure, kept apart from faults

Today `Checkpoint_trials.attempts` counts mg-05's battle luck and a broken reader alike, and the hard
stop ("the same step failed twice") would stop a 3% roll after two tries. A roll is a checkpoint whose
attempt can end lost without anything being wrong:

```ocaml
(* engine/checkpoints/run/roll.mli *)
type t = { chance : float; confidence : float; vary : string option }
  (* plan metadata "roll": {"chance": 0.03, "confidence": 0.99, "vary": "wait_then_step"};
     [vary] names a fragment run after each reload, before the attempt *)

val budget : t -> int
  (* attempts so the roll is won with [confidence]: ceil (log (1 - c) / log (1 - p));
     152 at 3% and 90 at 5% (c = 0.99), 99 at 3% (c = 0.95) *)

(* Game.outcome gains a second success *)
type done_ = Done | Lost of string        (* "the NPC refused": read, not a fault *)
type outcome = (done_, Failure.cause) result

type attempt = Won | Lost_roll of string | Fault of Checkpoint_trials.failure

type verdict =
  | Roll_again
  | Roll_won of { attempts : int }
  | Roll_spent of { attempts : int }       (* the budget ran out: bad luck or a wrong [chance] *)
  | Faulted of { at : string; why : string } (* the hard stop and retries apply to faults only *)
```

A lost roll reloads the checkpoint's start and goes again; it never counts toward the hard stop or
`retries`, which keep their meaning for faults. The handler (the game's `beg` action) returns `Lost`
only after reading the refusal; a screen it does not recognise is a fault. Each attempt is logged
and `run.json` records attempts and wins, so the real rate can replace `chance` later. Verification
of a roll checkpoint counts a run as passed when its attempts ran clean (won or lost, no fault), so
three verifying runs do not need three wins.

### b. The start: an emulator state or an in-game save

Today mGBA loads a `.ss` state (`Checkpoint_run.options.state`, `Event_states`), and on the Switch
`Console_runs` decides "return to the last save, check the start; after a pass save in game", which
`bin/console_session.ml` binds to FireRed's `Soft_reset.return_to_save`, `Start_check` (kept frame,
party) and `Game_save.save_game`. The decision is agnostic; the binding is the part to lift:

```ocaml
(* engine/checkpoints/series/console_start.mli *)
type start =
  | Emulator_state of { path : string }      (* mGBA: load_state; event states and partial runs work *)
  | Game_save of { slot : int option }       (* console: the game's save, [slot] for a game with several *)

type game_steps = {
  return_to_save : slot:int option -> (unit, Failure.cause) result;
      (* FireRed: soft reset, CONTINUE, recap. Octopath 0: its load from the menu or title *)
  save_in_game : slot:int option -> (unit, Failure.cause) result;
  check_start : unit -> Postcondition.result list;  (* FireRed: kept frame and party; Octopath 0: zone read *)
  relaunch : unit -> (unit, string) result;
      (* the fallback when [return_to_save] fails: close from HOME and start the game (switch_home) *)
}
```

`Console_runs.step` runs over this record instead of FireRed's modules, and `bin/console_session.ml`
becomes generic. A game with no emulator has no event states, so `--from-event` refuses as it does on
the Switch today (`Event_range.check`).

### c. Movement without a tile grid

`Pose.zone` (place, spot, heading) already decodes and is never checked. Octopath 0's own walk:

```ocaml
(* games/octopath0, an own_kind *)
type push = { toward : Direction8.t; hold_ms : int }   (* D-pad, or the stick if needed *)
type walk = {
  pushes : push list;           (* as written in the plan or the places table, never planned *)
  arrive : landmark;            (* the reader that proves arrival *)
  timeout_ms : int;
}
and landmark =
  | Prompt of string            (* the interaction prompt shows: "talk", "enter" *)
  | Zone_name of string         (* the zone name on entering, or on the map screen *)
  | Template of string          (* a fixed landmark's template in a box *)
```

A walk passes when its landmark reads before the timeout; the observed position is the zone and spot
of the last landmark read, so `declared_after` zones get checked (the runner stops ignoring zones). A
walk whose landmark does not read re-anchors with a fragment that ends somewhere certain (leave the
zone and come back: entry points are fixed), then tries once more. Durations drift, so walks stay
short and each ends on a landmark. No grid, map data or planner for this game until a program shows it
needs one.

### d. The game folder

```
src/games/octopath0/
  checkpoints/   Octopath0_terms (zone pose, own kinds: walk, rest, battle round; promises:
                 levels, equipped), Octopath0_checkpoints = Make (Octopath0_terms), Game.t,
                 Console_start.game_steps, pre-flight
  readers/       beg result, enemy names (the cat), zone name, prompt, menus, load menu
  actions/       beg, walk (pushes until a landmark), rest_at_inn, shop, equip
  battle/        Cat_battle: the deciding module and its game_steps (read_enemies, run_sequence, flee)
  places/        places.json: zones and spots, and the pushes from a zone's entry to each spot
  fragments/     fragments.json: rest_at(town), re_anchor(zone)
  programs/beg_item/plans/, programs/cat_farm/plans/
  assets/        templates
```

Program 2 as plans: `cf-01` (prep; `shop`, `equip`; promises `equipped` and provides `cat-kit`),
`cf-02` (needs `cat-kit`; `repeat` until `levels` at least 60; a round is `walk` into the zone,
`battle_round` (Cat_battle decides kill or flee), `rest_at(town)` when HP is low through `skip_if`),
`cf-03` (`rest_at`, save). The registry gets `game_id = "octopath0"`, backends `[Switch]`.

## 4. Migration

Each PR keeps every FireRed plan, test and run as it is. **S** marks a structural PR (user review);
the groups run in parallel inside, in order between.

| # | PR | S | After |
|---|---|---|---|
| 1 | `Json_field` to `src/base/json_field`; `Repo_files`, `Json_file` to `src/base/repo_io`. Moves only | S | |
| 2 | The `engine` layer and game families in the lint config; `src/engine/checkpoints/expand` gets the four agnostic expand modules; `series` gets `Chain_progress`, `Checkpoint_order`, `Round_trials`; `run` gets `Checkpoint_trials`, `Event_progress`. Moves only | S | 1 |
| 3 | `Postcondition` (first named `Promise`): the agnostic half of `Postcondition_check` | S | 1 (parallel with 2) |
| 4 | `GAME_TERMS` and `Engine_checkpoints.Make`; `Pokemon_terms`; the rest of `plan` and `run` moved; a toy-game test with zones. Golden test: every plan in the repo prints the same `Plan_text` before and after | S | 2, 3 |
| 5 | `Game_commands.S` and `bin/` over it; FireRed's module out of `bin/` | S | 4 |
| 6 | `Roll`: outcome, budget, verdict, scripted-game tests | S | 4 (parallel with 5) |
| 7 | `Console_start` and `Console_runs` over it; FireRed's binding | S | 5 |
| 8 | Daemon: a native Switch viewport (8a, `--viewport native`) and both sticks on `press` (8b, `protocol/`). Claimed by the PLZA port (2026-11-25) | 8b | any time |
| 9 | `games/octopath0` skeleton, registry entry, readers for the beg result; program 1 | S | 6, 7, 8 |
| 10 | Zone walks and landmark readers. First user: PLZA 01.01 (`plza-autostory-port.md`); then program 2's `Cat_battle` and plans | S (format) | 4, 8 |

1, 3 and 8 can start at once; 5 and 6 run side by side after 4. Program 1 does not wait for 10.
PLZA 01.01 is the first game on the engine after 4 and the first user of 8 and 10, before Octopath 0:
its C++ steps and timings passed on the console, so a failure points at the engine, not the game.

## 5. Open questions

1. **Functor or type parameters for the game's types?** Recommendation: the functor, applied once per
   game family; type parameters if its `.mli`s prove hard to read in PR 4.
2. **Does reloading the save reroll the Beg?** Recommendation: measure before coding `vary`: 20 reloads
   with no change, then 20 with a wait. If the result never changes without a wait, `vary` is a wait
   drawn through the RNG boundary (so replays repeat it), as the fork's soft reset spreads frames with
   random waits; a step only if waits do not reroll.
3. **Which save slot is GamePilot's?** Recommendation: one slot named in the goal file; the runner
   saves and reloads only that slot, and refuses a run whose slot is unset. The player's other slots are
   never written.
4. **How is a game without an emulator tested before the Switch?** Decided (user, 2026-11-25):
   reader and game tests, a scripted run (a lost walk included) and a wire-log replay in CI, then
   three console passes in a row; AGENTS.md says so.
5. **D-pad or stick?** Decided (user, 2026-11-25): `press` takes optional `left_stick` and
   `right_stick` ([x, y] in -1..1, centred when absent), since PLZA walks, runs (B with the stick)
   and needs both. Octopath 0 may still walk on the D-pad.
6. **Roll confidence.** Recommendation: 0.99 by default (152 attempts at 3%, about one to two hours
   at 30-60 s each), with the attempt cap settable in the goal file; a spent budget stops and reports
   the observed rate.
7. **Reload path in Octopath 0.** Recommendation: the game's own load (menu or title) as
   `return_to_save`, and close-and-relaunch from HOME (`switch_home`) only as the fallback, since it
   is slower and depends on the HOME readers working on a native game's picture.
