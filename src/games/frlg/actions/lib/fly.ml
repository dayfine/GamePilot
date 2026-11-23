type plan = { town : Fly_towns.town; slot : int; menu_row : int }

let fly_map_wait_ms = 4000
let member_menu_gone m = not (Party_actions.member_menu m)

let to_fly_map plan =
  Party_actions.open_party ();
  Party_actions.on_member_menu plan.slot (fun () ->
      Party_actions.choose_member_row (plan.menu_row - 1)
        ~taken:member_menu_gone);
  ignore
    (Effects.submit [ Wire.Wait { wait_ms = fly_map_wait_ms } ]
      : Wire.batch_done)

let press button =
  Wire.Press
    {
      buttons = [ button ];
      hold_ms = Menu_input.button_hold_ms;
      cooldown_ms = 0;
    }

(* After the landing's settle, how long the screen may take to show another
   scene than the departure town before Fly fails: the settle has seen the
   overworld quiet by then, so this only covers the look's lag. *)
let left_departure_ms = 2000

(* The overworld before the party opens: the scene Fly must leave. *)
let departure () =
  match
    Effects.await ~timeout_ms:Menu_input.screen_timeout_ms (fun m ->
        Option.is_some (Frlg_readers.Scene_signature.read m))
  with
  | Holds m -> Frlg_readers.Scene_signature.read m
  | Timeout -> None

(* The fork's landing judge (judge_fly_landing()): a fade and a quiet
   overworld (the warp settle), then the screen no longer the departure
   town's; its facing read has no reader here. *)
let no_landing detail = Error (Story.Failure.cause "fly_no_landing" detail)

let left_departure before =
  match
    Effects.await ~timeout_ms:left_departure_ms
      (Frlg_readers.Scene_signature.left ~before)
  with
  | Holds _ -> true
  | Timeout -> false

let landed ~log plan departure =
  let town = plan.town.Fly_towns.name in
  match departure with
  | None -> no_landing "no screen before the Fly"
  | Some before when left_departure before ->
      log ("Fly: landed in " ^ town ^ ".");
      Ok ()
  | Some _ -> no_landing (town ^ ": the screen still shows the departure town")

let fly_steps ~log plan =
  let departure = departure () in
  log
    (Printf.sprintf "Fly with slot %d, menu row %d, to %s (cell %d, %d)."
       plan.slot plan.menu_row plan.town.name plan.town.cell.x plan.town.cell.y);
  match to_fly_map plan with
  | exception Menu_input.Action_failed cause -> Error cause
  | () ->
      ignore
        (Effects.submit (Fly_towns.cursor_presses plan.town @ [ press Wire.A ]));
      Result.bind
        (Scene_looks.settle After_warp
           ~label:("fly to " ^ plan.town.name)
           ~battle_ends:false ~log)
        (fun () -> landed ~log plan departure)

let fly ~log plan =
  Effects.with_probes (Menu_input.probes @ Frlg_readers.Scene_signature.probes)
    (fun () -> fly_steps ~log plan)
