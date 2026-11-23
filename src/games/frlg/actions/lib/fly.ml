open Frlg_readers

type plan = { town : Fly_towns.town; slot : int; menu_row : int }

let member_menu_wait_ms = 1000
let fly_map_wait_ms = 4000
let pokemon_row = 1
let menu_timeout_ms = 3000
let menu_tap_ms = 80
let menu_release_ms = 240
let button_hold_ms = 160

let press ?(cooldown_ms = 0) button =
  Wire.Press { buttons = [ button ]; hold_ms = button_hold_ms; cooldown_ms }

let menu_moves ~from ~to_ =
  let button = if to_ >= from then Wire.Down else Wire.Up in
  let tap =
    Wire.Press
      {
        buttons = [ button ];
        hold_ms = menu_tap_ms;
        cooldown_ms = menu_release_ms;
      }
  in
  List.init (abs (to_ - from)) (fun _ -> tap)

exception Fly_failed of Story.Failure.cause

let await_or code what pred =
  match Effects.await ~timeout_ms:menu_timeout_ms pred with
  | Holds m -> m
  | Timeout ->
      raise (Fly_failed (Story.Failure.cause code (what ^ " did not open")))

let to_fly_map plan =
  ignore (Effects.submit [ press Wire.Start ]);
  let m =
    await_or "fly_no_start_menu" "the Start menu" Start_menu.start_menu_open
  in
  let row = Option.value (Start_menu.cursor_row m) ~default:0 in
  ignore
    (Effects.submit (menu_moves ~from:row ~to_:pokemon_row @ [ press Wire.A ]));
  ignore (await_or "fly_no_party" "the party" Party_menu.party_menu);
  ignore
    (Effects.submit
       (menu_moves ~from:1 ~to_:plan.slot
       @ [ press Wire.A ~cooldown_ms:member_menu_wait_ms ]
       @ menu_moves ~from:1 ~to_:plan.menu_row
       @ [ press Wire.A ~cooldown_ms:fly_map_wait_ms ]))

let fly_steps ~log plan =
  log
    (Printf.sprintf "Fly with slot %d, menu row %d, to %s (cell %d, %d)."
       plan.slot plan.menu_row plan.town.name plan.town.cell.x plan.town.cell.y);
  match to_fly_map plan with
  | exception Fly_failed cause -> Error cause
  | () ->
      ignore
        (Effects.submit (Fly_towns.cursor_presses plan.town @ [ press Wire.A ]));
      Scene_looks.settle After_warp
        ~label:("fly to " ^ plan.town.name)
        ~battle_ends:false ~log

let fly ~log plan =
  Effects.with_probes Menu_input.probes (fun () -> fly_steps ~log plan)
