open Frlg_readers

exception Trainer_battle
exception Message_stuck

let late_wild_battle_delay_ms = 3700

(* mGBA, 2026-11-23, run 4 of mg-04: the flash watcher fired 13 frames after
   the step that set the battle off. 15 frames places the step within half a
   tile either way, walking (16 frames a tile) or running (8). *)
let wild_flash_delay_ms = 250

(* A hold's release can leave a step to finish (16 frames), and the flash
   fires 13 frames after it. *)
let flash_watch_ms = 600
let trainer_battle_watch_ms = 6000

(* The box shows as the step ends; then video lag. Not calibrated yet. *)
let message_delay_ms = 400

(* B presses that close a message: up to 5, a second apart. *)
let max_b_presses = 5
let b_hold_ms = 160
let b_cooldown_ms = 840
let probes = Screen_facts.probes

let wild_flash ~flee : Grid_walker.Leg_interrupt.t =
  {
    name = "a wild battle";
    kind = Wild_battle;
    seen = Battle_flash.seen (Battle_flash.create ());
    detection_delay_ms = wild_flash_delay_ms;
    clear = flee;
  }

let wild_battle ~flee : Grid_walker.Leg_interrupt.t =
  {
    name = "a wild battle (seen late)";
    kind = Wild_battle;
    seen = Battle_screen.battle_shows;
    detection_delay_ms = late_wild_battle_delay_ms;
    clear = flee;
  }

let closed m = not (Dialog.dialog_up m)

let press_b () =
  Wire.press ~hold_ms:b_hold_ms ~cooldown_ms:b_cooldown_ms [ Wire.B ]

let rec close_message presses =
  if presses >= max_b_presses then raise Message_stuck
  else
    match Effects.race [ press_b () ] ~stop:closed with
    | Stopped _ -> ()
    | Finished _ -> (
        match Effects.read () with
        | Some m when closed m -> ()
        | _ -> close_message (presses + 1))

let clear_message () =
  close_message 0;
  match
    Effects.await ~timeout_ms:trainer_battle_watch_ms Battle_screen.battle_shows
  with
  | Holds _ -> raise Trainer_battle
  | Timeout -> ()

let message () : Grid_walker.Leg_interrupt.t =
  {
    name = "a message";
    kind = Dialogue;
    seen = Dialog.dialog_up;
    detection_delay_ms = message_delay_ms;
    clear = clear_message;
  }

let for_leg ~flee ~wild =
  if wild then [ wild_flash ~flee; wild_battle ~flee; message () ]
  else [ message () ]
