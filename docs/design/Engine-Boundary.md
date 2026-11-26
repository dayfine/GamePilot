# Engine boundary: the checkpoint engine apart from Pokémon (draft, 2026-11-25)

GamePilot's checkpoint engine (program, goal, checkpoints, plan, event, inputs: `Programs-As-Goals.md`)
lives under `src/pokemon/checkpoints`, and much of it is Pokémon- or grid-specific. A second game,
not a Pokémon one and without a tile grid, is coming soon: Octopath Traveler 0 on the Switch. This
note says what was game-agnostic before the move (section 1), the engine's layout as built and how a
game plugs in its own parts (section 2), and the few new concepts the first two Octopath programs
need. Every move is its own PR, and nothing here is ported ahead of a program that needs it.

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

What the move started from: the files as they stood under `src/pokemon/checkpoints` before step 4.
**A** game-agnostic as it is; **G** tied to the tile grid; **P** tied to Pokémon; **mixed** says
which part is which. `Grid_maps` is `src/pokemon/navigation/grid/maps`.

### `pokemon/checkpoints/plan` (`checkpoints_plan`)

| File | | What ties it |
|---|---|---|
| `plan.mli` | mixed | A: `event` (id, way, why, `skip_if`, `once_per_save`), `checkpoint`, `t` (game, execution, metadata, retries, repeat), `count`, `money`, `Talk`, `Answer`, `Scene`, `Save`, `Named_action`. G: `leg`, `route`, `Route`, `Ready`, `Legs`, `Step` (`Grid_maps.Direction`). P: `party`, `slot`, `knows`, `level`, `marks`, `coins`, and the built-ins `Battle`, `Train`, `Heal`, `Shop`, `New_game`, `Game_settings` as FireRed runs them |
| `pose.ml` | mixed | G: `grid` (map, tiles, facing), `observed` (map, tile), `matches`. A: `zone` (place, spot, heading), already decoded and never used |
| `plan_decode.ml` | mixed | A: format names, strictness, unique ids, the event loop. G and P: the kind table and its args, grid poses |
| `plan_fields.ml` | mixed | A: field readers. G: `grid_pose`; P: `item` |
| `postcondition_decode.ml` | mixed | A: `items`, `money`, `flags`. P: `party`, `coins`, `caught`, `knows`, `levels`, `marks`. G: `position` |
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
| `postcondition_check.ml` | mixed | A: `verdict`, `result`, `unmet`, `log_lines`, the count and money comparisons against the start. P: `observed` and `start` fields (party, coins, caught, knows, levels, marks) |
| `checkpoint_trials.ml` | A | runs, passes, the hard stop, attempts. But an attempt lost to luck and one lost to a fault are the same `Attempt_failed` |
| `event_range.ml`, `event_progress.ml` | A | partial runs need a backend that keeps states (mGBA) |
| `event_snapshot.ml` | mixed | A: tracker. Emulator-bound: `.ss` files. P and G: `kept` holds Pokémon start reads and a grid position |
| `repeat_until.ml` | mixed | A: the loop. P: the `Heal` chore; raises `Invalid_argument` (waived) |
| `room_policy.ml` | P | party room and the PC |

### `pokemon/checkpoints/series` and `plan_text`

| File | | What ties it |
|---|---|---|
| `chain_progress.ml`, `checkpoint_order.ml`, `round_trials.ml` | A | |
| `console_runs.ml` | A | the decision is agnostic (its doc says "soft reset"); the steps are bound to FireRed in `games/frlg/series/lib/console_session.ml` |
| `plan_text.ml` | mixed | A: `event`, `outline`, `count_text`. G and P: kinds, poses, postconditions as text |

### `core` and around it

| Library | | What ties it |
|---|---|---|
| `effects`, `session`, `live`, `replay`, `run_record`, `watch_report` | A | |
| `screen_state` | A | facts (fade, banner, dialog, battle, free control, stillness) and the settle rules are shared by every game; the timings were measured on FireRed and a game may give its own `rule` |
| `switch_home` | mixed | A: parking and resuming on HOME. Tied to the GBA picture: boxes clipped to FireRed's `GAME_BOX` viewport, tests on FireRed's tile |
| `games/frlg/repo_files` | A | `Repo_files.locate`, `Json_file`: agnostic, but under FireRed, and `program_registry` depends on it |
| `bin/` | A | names no game module but in `bin/checkpoint_families.ml`, which picks a family's libraries by the registry's `rules` (FRLG's `games/frlg/series`, its ctl readers, `start_menu_poc`); per-game data (delete-save icons, the lab console's panel and HOME tile) is the registry's |
| `dev/lint/ocaml_lint.conf` | mixed | layer `game` may use `pokemon`: nothing stops a non-Pokémon game from using Pokémon code |
| `daemon/src/viewport.h` | G | only `nso_gba_viewport` (240 x 160 inside the Switch frame); a native Switch game is the whole 1920 x 1080 frame |
| `Wire.command` | A | buttons (ZL, ZR, Plus and Minus by protocol v1.17, the left stick's click LStick from v1.18), waits and both analog sticks (v1.12) |

In short: the skeleton (run order, skips, trials, rounds, chains, fragments, the watch page, the
records) is agnostic already. The grid and Pokémon parts are three types (where the player is, the
game's actions, what a checkpoint promises) and the code that reads, prints and checks them.

## 2. Layout: a game's rules apart from its formats

A game's rules and its formats are separate libraries. The rules (where the player stands, the
game's actions, what a checkpoint promises and its check) are plain values with no JSON, and each
part prints itself (`to_string`, `to_lines`), purely. Each format turns them into bytes at one edge
only, so the plan types, the runner, its failures and the checks never see JSON. A lint rule
enforces it.

The rules were first called terms (`Engine_terms.TERMS`, `Pokemon_terms`, `Terms_text`); they were
renamed `Engine_rules.GAME_RULES`, `Pokemon_rules` and `Rules_text` on 2026-11-25, unchanged. The
game's own kinds were renamed its actions the same day, also unchanged: `KIND` and `Kind` became
`ACTION` and `Action`, `Own_kind` `Pokemon_action`, the plan's `Own` and `Game_action` `Game` and
`Named_action`, and the event's `action` field `way` (its JSON key stays `"action"`). Later
the same day `kind_of_plan` became `action_of_plan`, `TEXT.kind` `action`, `Kind_decode` and
`Kind_text` `Pokemon_action_decode` and `Pokemon_action_text`, and the planner's `Leg.action`
`Leg.special_step`. Then (`Composable-Rules.md`, step 0) `Engine_checkpoints.Make` became
`Program_engine.Make`, `*_plan_codec` and `PLAN_CODEC` `*_plan_format` and `PLAN_FORMAT`, `*_saved`
and `Event_states.SAVED` `*_event_snapshot` and `Event_snapshot.SNAPSHOT`, `Pokemon_checkpoints`
`Pokemon_engine`, and `src/engine/checkpoints/` lost its `checkpoints` level, unchanged. In step
0b each `*_text` folded into its rules module (`Pose_text.grid` became `Pose.grid_to_string`,
`TEXT.pose` `Pose.to_string`, `TEXT.observed` `Pose.observed_to_string`, `TEXT.action`
`Action.to_string`, `TEXT.postconditions` `Postconditions.to_lines`), `Rules_text.TEXT`,
`Pokemon_text` and `Toy_text` went, and `Make` took three arguments; every plan prints the same.

What follows is one `GAME_RULES` per family, as built. How a game builds its rules from shared
pieces (a pose, action sets, promises), so that FRLG, PLZA and Octopath 0 each take only the parts
they use and FRLG's own actions stop being raw JSON, is `Composable-Rules.md`.

| Part | Engine signature | Pokémon | Toy game | Used by | Holds |
|---|---|---|---|---|---|
| Rules | `Engine_rules.GAME_RULES` | `Pokemon_rules` | `Toy_rules` | everything | values and `matches`, `check`, `to_string`, `to_lines` |
| Plan format | `Plan_format.PLAN_FORMAT` | `Pokemon_plan_format` | `Toy_plan_format` | `Plan_decode` only | hand-written JSON readers |
| Event snapshot | `Event_snapshot.SNAPSHOT` | `Pokemon_event_snapshot` | `Toy_event_snapshot` | `Event_snapshot` only | derived JSON (`ppx_deriving_yojson`) |

### The rules

`src/engine/rules/lib/engine_rules.mli`:

```ocaml
module type POSE = sig
  type t                    (* where a plan says the player stands: a grid pose, a zone *)
  type observed             (* where the game reads the player *)
  val matches : t -> observed -> bool
  val to_string : t -> string
  val observed_to_string : observed -> string
end
module type ACTION = sig
  type t                    (* the game's actions, with their args: route, battle; walk, rest *)
  val to_string : t -> string
end
module type POSTCONDITIONS = sig
  type t                    (* metadata.postconditions, a repeat's until *)
  type reads                (* what the game read for them, start reads included *)
  val check : t -> reads -> Engine_postcondition.Postcondition.result list
  val to_lines : t -> string list
end
module type GAME_RULES = sig
  module Pose : POSE
  module Action : ACTION
  module Postconditions : POSTCONDITIONS
end
```

| Game | `Pose.t` / `observed` | `Action.t` | `Postconditions.t` / `reads` |
|---|---|---|---|
| Pokémon | `Grid of grid \| Zone of zone` (a zone holds anywhere) / map and tile (`Grid_geometry`) | `Pokemon_action.t`: new game, options, route, ready, legs, step, battle, train, heal, shop | party, items, coins, caught, money, flags, moves, levels, marks / `Postcondition_check.observed` (with `start`) |
| Toy | `{ place; spot }` / the same | `Walk`, `Rest` | gold (`Count.t`), flags / gold now and at the start, flags set |

`check` takes the reads alone: what the game read at the checkpoint's start is part of `reads`. The
game reads its postconditions through a function handed to the runner with them
(`Runner.run ?end_state:(postconditions, read)`, FireRed's `Postcondition_reads`); the engine orders
the check and logs it. A plan holds its postconditions as an option, and the runner reads the end
state only when given one. The engine owns no promise fields: a plan's `postconditions` is one
object, the game's, decoded once with its known fields checked, and logged in the game's order. What
the engine gives instead are parts in `postcondition/`: `Postcondition` (result, verdict, log lines),
`Count` and `Money` (a value, floor, range or change from the start, and their checks).

The plan's types are `Engine_plan.Plan.Make (T) (Raw)`: the engine's kinds `Talk`, `Answer`,
`Scene`, `Save`, `Named_action of Raw.t` and `Game of T.Action.t`. `Raw` is what the plan keeps unread
(a game action's args, `execution`, `metadata`); the engine applies it to `Raw_json` from the plan format
library, so `plan/` itself links no JSON.

### Each format on its own

```ocaml
(* plan_format/lib/plan_format.mli: only Plan_decode calls these *)
module type PLAN_FORMAT = sig
  module T : Engine_rules.GAME_RULES
  val pose_of_plan : where:string -> Json_field.obj -> (T.Pose.t, string) result
  val action_of_plan :
    string -> (where:string -> Json_field.obj -> (T.Action.t, string) result) option
      (* [None]: the kind name is not this game's *)
  val postconditions_of_plan :
    where:string -> Json_field.obj -> (T.Postconditions.t, string) result
end

(* event_snapshot/lib/event_snapshot.mli: only Event_snapshot calls these *)
module type SNAPSHOT = sig
  type t                    (* the start reads and where the player was reckoned to stand *)
  val to_yojson : t -> Yojson.Safe.t
  val of_yojson : Yojson.Safe.t -> (t, string) result
end
```

- **Plan format, hand-written.** A plan is written by hand, so a bad one must say where:
  `01-celadon-setup.plan.json: checkpoint.events[1].args.target.map is missing.` Every reader takes
  `where`, the field prefix, and the engine's `Plan_decode` passes any kind name it does not know to
  `action_of_plan`. The plan format did not change.
- **Text, beside each type.** Each part of the rules prints itself, purely: `Pose.to_string`,
  `Pose.observed_to_string`, `Action.to_string`, `Postconditions.to_lines`. `Plan_text` prints a
  decoded plan with them (the golden plan test compares it), and `Failure_text` and `Run_text` print
  what the runner kept.
- **Event snapshot, derived.** A machine writes and reads `<n>-<event>.json` beside each event state, so its
  JSON is derived with `[@@deriving yojson]`. The derivation sits in `Pokemon_event_snapshot` and
  `Toy_event_snapshot`, on copies of the rules' types (`type observed = Pose.observed = { ... } [@@deriving yojson]`), so
  the rules libraries need no ppx. A bad file's error names the type or field
  (`Pokemon_event_snapshot.observed.at_map`); older files with fewer fields still load.

**Naming.** The hand-written plan side is `*_of_plan` (`pose_of_plan`, the Pokémon decoders in
`Pose_decode`, `Pokemon_action_decode`, `Postcondition_decode`, `Party_decode`); the derived snapshot
side keeps the ppx's `to_yojson` / `of_yojson`; text is `to_string` (`to_lines` for promises).

### The functor

```ocaml
module Make
    (T : Engine_rules.GAME_RULES)
    (C : Engine_plan_format.Plan_format.PLAN_FORMAT with module T = T)
    (S : Engine_event_snapshot.Event_snapshot.SNAPSHOT) : sig
  module Plan            (* Plan.Make (T) (Raw_json) *)
  module Plan_decode     (* over C *)
  module Plan_text       (* over T's printing *)
  module Failure         (* Failure.Make (T), and Failure_text over T *)
  module Game            (* the handlers: run_own, run_builtin, game_actions, flag_holds,
                            position, between_rounds, save, reload, log *)
  module Runner          (* run ?end_at ?end_state ?on_event ?events; its lines printed to game.log *)
  module Event_snapshot  (* the state files, and Make (S) for what is kept beside them *)
  module Repeat_until    (* a looped checkpoint, and stop_to_string *)
end
```

`T` stands alone and comes first so that every module inside is applied to the same path `T`: the
plan's types are then one type for the decoder, the text and the runner, and `C` is pinned to it by
`with module T = T`. Were the rules a part of one big game module, each format would drag the other
along, and the rules libraries could not be kept free of JSON. `S` needs no `T`:
what it keeps is the game's own record.

Pokémon applies it once, `Pokemon_engine = Make (Pokemon_rules) (Pokemon_plan_format)
(Pokemon_event_snapshot)`, and FireRed uses that. The engine's tests apply it to the
toy game (`program_engine/test`: zones, no grid, gold and flags), which is what proves the boundary.

### Failures and log lines carry values

The runner never formats a game's term. A failure keeps the poses and results as values, and a log
line is a list of parts:

```ocaml
type reason =                                     (* Failure.Make (T) *)
  | Handler of cause | No_handler of string
  | Not_at_declared of { declared : T.Pose.t; observed : T.Pose.observed }
  | Not_at_end of { declared : T.Pose.t; observed : T.Pose.observed option }
  | Unmet_postconditions of Postcondition.result list

type part = Text of string | Pose of T.Pose.t     (* Log_line.Make (T) *)
          | Reason of Failure.Make(T).reason | Failure of Failure.Make(T).t
```

Text is made at the edge: `Make`'s `Runner` prints each line with `Run_text.line` to `game.log`, and
`Failure.to_string` is `Failure_text`'s. A test can match a failure's pose without parsing a string.

### The lint rule

`never_links DIR LIB...` in `dev/lint/ocaml_lint.conf` fails a `dune` stanza in `DIR` that links one
of the libraries, directly or through any library of the tree, however deep:

| Directory | Never links |
|---|---|
| `src/engine/{rules,postcondition,plan,run}/lib` | `yojson`, `json_field`, `wire`, `engine_plan_format`, `engine_text`, `engine_event_snapshot` |
| `src/pokemon/checkpoints/rules/lib` | the same, and `pokemon_plan_format`, `pokemon_event_snapshot` |

The layers stay one-way as before: `allow engine engine core base`, `allow pokemon pokemon engine
core base`, and a game uses `pokemon` only when its family lists it (`family pokemon game frlg plza`), so
`octopath0` cannot.

### Folders

```
src/base/json_field/            Json_field: field readers returning Result
src/base/repo_io/               Repo_files, Json_file
src/engine/
  rules/                        Engine_rules: POSE, ACTION, POSTCONDITIONS, GAME_RULES
  postcondition/                Postcondition, Count, Money
  plan/                         Plan.Make (T) (Raw): types only
  run/                          Game, Runner, Failure, Log_line, Repeat_until, Checkpoint_trials,
                                Event_range, Event_progress
  plan_format/                  PLAN_FORMAT, Plan_decode, Plan_fields, Raw_json
  text/                         Plan_text, Failure_text, Run_text
  event_snapshot/               SNAPSHOT, Event_snapshot
  program_engine/               Program_engine.Make; test/: the toy game (Toy_rules, Toy_plan_format,
                                Toy_event_snapshot, Toy_engine)
  series/                       Chain_progress, Checkpoint_order, Round_trials
  expand/                       Plan_json, Table_decode, Fragment_table, Fragment_calls
src/pokemon/navigation/grid/geometry/   Grid_geometry: Tile_pos, Direction (pure; the rules use it)
src/pokemon/checkpoints/
  rules/                        Pokemon_rules: Pose, Pokemon_action, Postconditions, Postcondition_check
  plan_format/                  Pokemon_plan_format: Pose_decode, Pokemon_action_decode,
                                Postcondition_decode, Party_decode
  event_snapshot/               Pokemon_event_snapshot
  instance/                     Pokemon_engine = Program_engine.Make (...)
  checkpoint_end/               Checkpoint_end: the declared end as a grid pose
  room_policy/                  Room_policy: party room and the PC
  series/                       Console_runs, until Console_start (section 3b) moves it to the engine
  expand/                       Place_routes (grid, lifts)
src/games/frlg/                 opens Pokemon_engine
src/games/octopath0/            section 3d
```

`Checkpoint_end` stays in Pokémon: the declared end is a grid pose from the next start, the last
route or ready target, or a `position` promise; the runner takes it as `?end_at:T.Pose.t`.
`Event_range` takes event ids, not events, so it is a plain module.

### Why a functor

| | Functor (chosen) | Type parameters | Extensible variants |
|---|---|---|---|
| Shape | `Make (T) (C) (X) (S)` once per family | `('pose, 'kind, 'promises) Plan.t`, and so on | `type action += ...`, decoders registered by name |
| Engine signatures | plain inside the functor | two or three type variables wherever a plan, failure or game is named | plain |
| Game code | concrete types, exhaustive matches | concrete, annotations everywhere | a catch-all case in every match |
| Cost | heavier `.mli`s and errors | noisy signatures for every reader | weakest checking |

Keeping the game's parts as raw JSON (as `Named_action` args are) is rejected: errors would show at
run time, not when the plan loads.

`bin/` will pick a game by the registry's `game_id` and call that game's command module, a
first-class module of one signature (`Game_commands.S`: load plans, build `Game.t`, the console start
of section 3b, the pre-flight). FireRed's is today's code moved out of `bin/`.

## 3. New engine concepts

### a. A roll: expected failure, kept apart from faults

Today `Checkpoint_trials.attempts` counts mg-05's battle luck and a broken reader alike, and the hard
stop ("the same step failed twice") would stop a 3% roll after two tries. A roll is a checkpoint whose
attempt can end lost without anything being wrong:

```ocaml
(* engine/run/roll.mli *)
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

Today mGBA loads a `.ss` state (`Checkpoint_run.options.state`, `Event_snapshot`), and on the Switch
`Console_runs` decides "return to the last save, check the start; after a pass save in game", which
`games/frlg/series/lib/console_session.ml` binds to FireRed's `Soft_reset.return_to_save`, `Start_check` (kept frame,
party) and `Game_save.save_game`. The decision is agnostic; the binding is the part to lift:

```ocaml
(* engine/series/console_start.mli *)
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

`Console_runs.step` runs over this record instead of FireRed's modules, and `games/frlg/series/lib/console_session.ml`
becomes generic. A game with no emulator has no event states, so `--from-event` refuses as it does on
the Switch today (`Event_range.check`).

### c. Movement without a tile grid

`Pose.zone` (place, spot, heading) already decodes and is never checked. Octopath 0's own walk:

```ocaml
(* games/octopath0, one of its actions *)
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
  checkpoints/   Octopath0_rules (zone pose, actions: walk, rest, battle round; promises:
                 levels, equipped), Octopath0_checkpoints = Make (Octopath0_rules), Game.t,
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
| 2 | The `engine` layer and game families in the lint config; `src/engine/expand` gets the four agnostic expand modules; `series` gets `Chain_progress`, `Checkpoint_order`, `Round_trials`; `run` gets `Checkpoint_trials`, `Event_progress`. Moves only | S | 1 |
| 3 | `Postcondition` (first named `Promise`): the agnostic half of `Postcondition_check` | S | 1 (parallel with 2) |
| 4 | `Engine_rules.GAME_RULES`, the three formats (`PLAN_FORMAT`, `TEXT`, `SNAPSHOT`) and `Program_engine.Make`; Pokémon's rules, plan format, text and event snapshot; the rest of `plan` and `run` moved; a toy-game test with zones. Golden test: every plan in the repo prints the same `Plan_text` before and after | S | 2, 3 |
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

1. **Functor or type parameters for the game's types?** Decided: the functor, applied once per game
   family over its rules and its three formats (section 2).
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
