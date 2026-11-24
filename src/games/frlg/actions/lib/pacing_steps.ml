open Frlg_readers
module Ow = Frlg_overworld

let walk_tap = Grid_maps.Move_mechanics.frlg.walk.tap

let step_tap d =
  Wire.Press
    {
      buttons = [ Menu_input.dpad d ];
      hold_ms = walk_tap.hold_ms;
      cooldown_ms = walk_tap.release_ms;
    }

(* step_once(): a turn first when the player faces another way; the release
   waits out the lockout before the next step tap. *)
let step ~pace spot () =
  let way = Pacing.way ~pace !spot in
  let turn =
    if !spot.facing = Some way then [] else Ow.Route_legs.turn_tap way
  in
  let flash = Ow.Battle_flash.create () in
  let seen =
    match
      Effects.race (turn @ [ step_tap way ]) ~stop:(Ow.Battle_flash.seen flash)
    with
    | Stopped _ -> true
    | Finished _ -> false
  in
  spot := Pacing.after_step ~pace !spot;
  seen

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

let steps ~log ~pace spot : Pacing.steps =
  {
    step = step ~pace spot;
    battle_shows = reads Battle_screen.battle_shows;
    overworld_shows;
    message_shows = reads Dialog.dialog_up;
    fight_trainer;
    log;
  }

let find_encounter ~log ~pace spot =
  Effects.with_probes Ow.Walk_interrupts.probes (fun () ->
      Pacing.pace_until_battle (steps ~log ~pace spot)
        ~max_steps:Pacing.max_steps)
