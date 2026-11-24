type spot = { displaced : bool; facing : Grid_maps.Direction.t option }

let on_patch facing = { displaced = false; facing }

let way ~pace spot =
  if spot.displaced then Grid_maps.Direction.opposite pace else pace

let after_step ~pace spot =
  { displaced = not spot.displaced; facing = Some (way ~pace spot) }

let stands_on ~pace spot tile =
  if spot.displaced then Grid_maps.Tile_pos.next tile pace else tile

type steps = {
  step : unit -> bool;
  battle_shows : unit -> bool;
  overworld_shows : unit -> bool;
  message_shows : unit -> bool;
  fight_trainer : unit -> string;
  log : string -> unit;
}

let max_steps = 200

(* The flash can be missed (console B, 2026-11-03): the battle's first text
   then waits for A, and the D-pad does nothing. A trainer who saw the player
   pace in his sight walks up and speaks (console B, 2026-11-03, Route 24). *)
let rec pace steps ~max_steps c =
  if c >= max_steps then false
  else if steps.step () then true
  else if steps.battle_shows () then (
    steps.log
      (Printf.sprintf
         "Pacing: a battle shows after step %d; its flash was missed." (c + 1));
    true)
  else (
    if steps.message_shows () then
      steps.log
        (Printf.sprintf
           "Pacing: trainer battle during pacing: %s, after step %d."
           (steps.fight_trainer ()) (c + 1));
    pace steps ~max_steps (c + 1))

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

let pace_until_battle steps ~max_steps =
  pace steps ~max_steps 0 || after_last steps ~max_steps
