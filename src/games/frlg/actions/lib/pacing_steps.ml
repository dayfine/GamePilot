open Frlg_readers
module Ow = Frlg_overworld

let mechanics = Grid_maps.Move_mechanics.frlg
let walk_tap = mechanics.walk.tap

let step_tap d =
  Wire.press ~hold_ms:walk_tap.hold_ms ~cooldown_ms:walk_tap.release_ms
    [ Menu_input.dpad d ]

(* How long after a step's first press its walk ends: the turn tap and its
   settle (Route_legs.turn_tap), then the tile. A battle the walk starts
   flashes after that; one the turn starts, before. On mGBA (2026-11-25, Route
   3) a walk's flash was seen 51 frames after a turn and step's first press,
   whose walk takes 36, and a turn's 23 frames after it. *)
let walk_ms ~turned =
  let turn = if turned then Ow.Route_legs.turn_ms else 0 in
  float (turn + mechanics.walk.tile.across_ms)

(* The first sign of a battle the watcher sees, kept for the race's end. *)
let watch_signs () =
  let watcher = Ow.Battle_flash.create () in
  let first = ref None in
  let stop m =
    match Ow.Battle_flash.sign watcher m with
    | Some sign ->
        first := Some sign;
        true
    | None -> false
  in
  (first, stop)

let sign_seen ~start first (m : Effects.measurements) : Pacing.sign option =
  match first with
  | Some Ow.Battle_flash.Flash -> Some (Flash_after (m.t_ms -. start))
  | Some Going_black -> Some Going_black
  | None -> None

(* step_once(): a turn first when the player faces another way; the release
   waits out the lockout before the next step tap. *)
let step ~pace (spot : Pacing.spot) =
  let way = Pacing.way ~pace spot in
  let turned = spot.facing <> Some way in
  let turn = if turned then Ow.Route_legs.turn_tap way else [] in
  let first, stop = watch_signs () in
  let start = Effects.now () in
  let seen =
    match Effects.race (turn @ [ step_tap way ]) ~stop with
    | Stopped m -> sign_seen ~start !first m
    | Finished _ -> None
  in
  Pacing.stepped ~walk_ms:(walk_ms ~turned) seen

let reads look () =
  match Effects.read () with Some m -> look m | None -> false

let fight_trainer () =
  Menu_input.fail "pace_trainer"
    "a trainer spoke during pacing; their battle is not ported"

(* The fork's overworld_shows: START opens the start menu only on the
   overworld; B closes it again. *)
let start_menu_wait_ms = 1200
let start_menu_close_ms = 600

let overworld_shows () =
  Menu_input.press ~cooldown_ms:start_menu_wait_ms Wire.Start;
  match Effects.read () with
  | Some m when Start_menu.start_menu_open m ->
      Menu_input.press ~cooldown_ms:start_menu_close_ms Wire.B;
      true
  | Some _ | None -> false

let steps ~log ~pace : Pacing.steps =
  {
    step = step ~pace;
    battle_shows = reads Battle_screen.battle_shows;
    overworld_shows;
    message_shows = reads Dialog.dialog_up;
    fight_trainer;
    log;
  }

let find_encounter ~log ~pace spot =
  Effects.with_probes Ow.Walk_interrupts.probes (fun () ->
      Pacing.pace_until_battle (steps ~log ~pace) ~pace spot
        ~max_steps:Pacing.max_steps)
