type spot = { displaced : bool; facing : Grid_geometry.Direction.t option }

let on_patch facing = { displaced = false; facing }

let way ~pace spot =
  if spot.displaced then Grid_geometry.Direction.opposite pace else pace

let after_step ~pace spot =
  { displaced = not spot.displaced; facing = Some (way ~pace spot) }

let stands_on ~pace spot tile =
  if spot.displaced then Grid_geometry.Tile_pos.next tile pace else tile

let spot_at ~pace ~patch tile facing =
  if Grid_geometry.Tile_pos.equal tile patch then Some (on_patch facing)
  else if
    Grid_geometry.Tile_pos.equal tile (Grid_geometry.Tile_pos.next patch pace)
  then Some { displaced = true; facing }
  else None

type sign = Flash_after of float | Going_black
type stepped = Walked | Battle_on_walk | Battle_on_turn | Battle_unflashed

let stepped ~walk_ms = function
  | None -> Walked
  | Some (Flash_after ms) when ms >= walk_ms -> Battle_on_walk
  | Some (Flash_after _) -> Battle_on_turn
  | Some Going_black -> Battle_unflashed

type steps = {
  step : spot -> stepped;
  battle_shows : unit -> bool;
  overworld_shows : unit -> bool;
  message_shows : unit -> bool;
  fight_trainer : unit -> string;
  log : string -> unit;
}

let max_steps = 200

let log_found steps c what =
  steps.log (Printf.sprintf "Pacing: %s at step %d." what (c + 1))

let after_trainer steps c =
  if steps.message_shows () then
    steps.log
      (Printf.sprintf "Pacing: trainer battle during pacing: %s, after step %d."
         (steps.fight_trainer ()) (c + 1))

(* Whether the step found a battle, the spot moved where it left the player. *)
let battle_found steps ~pace spot c : stepped -> bool = function
  | Battle_on_walk ->
      spot := after_step ~pace !spot;
      true
  | Battle_on_turn ->
      log_found steps c "a battle's flash before the walk: the turn started it";
      spot := { !spot with facing = Some (way ~pace !spot) };
      true
  | Battle_unflashed ->
      log_found steps c
        "a battle's wipe, its flash missed: the step did not move the player";
      true
  | Walked when steps.battle_shows () ->
      log_found steps c
        "a battle's screen after the step, its flash missed: the step did not \
         move the player";
      true
  | Walked ->
      spot := after_step ~pace !spot;
      false

(* The game looks for a wild battle at the end of a walk and at the end of a
   turn on the spot, and holds the player still from then on (mGBA,
   2026-11-25, Route 3: a flash 14 frames after a turn tap, the step tap after
   it walking nowhere). So a battle the step's turn started leaves the player
   on the tile, facing the step's way; one whose flash the step did not see
   (its wipe, or its screen after the step) was started before the step, which
   did not move the player. A trainer who saw the player pace in his sight
   walks up and speaks (console B, 2026-11-03, Route 24). *)
let rec search steps ~pace spot ~max_steps c =
  if c >= max_steps then false
  else
    battle_found steps ~pace spot c (steps.step !spot)
    ||
    (after_trainer steps c;
     search steps ~pace spot ~max_steps (c + 1))

let after_last steps ~max_steps =
  if steps.overworld_shows () then false
  else if steps.battle_shows () then (
    steps.log
      (Printf.sprintf
         "Pacing: a battle shows after the last of %d steps; its flash was \
          missed."
         max_steps);
    true)
  else (
    steps.log
      (Printf.sprintf
         "Pacing: no battle in %d steps, and the overworld doesn't show."
         max_steps);
    false)

let pace_until_battle steps ~pace spot ~max_steps =
  search steps ~pace spot ~max_steps 0 || after_last steps ~max_steps
