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

let steps ~log ~overworld_shows ~pace spot : Pacing.steps =
  {
    step = step ~pace spot;
    battle_shows = reads Battle_screen.battle_shows;
    overworld_shows;
    message_shows = reads Dialog.dialog_up;
    fight_trainer;
    log;
  }

let find_encounter ~log ~overworld_shows ~pace spot =
  Effects.with_probes Ow.Walk_interrupts.probes (fun () ->
      Pacing.pace_until_battle
        (steps ~log ~overworld_shows ~pace spot)
        ~max_steps:Pacing.max_steps)
