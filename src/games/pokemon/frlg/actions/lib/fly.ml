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
  Wire.press ~hold_ms:Menu_input.button_hold_ms ~cooldown_ms:0 [ button ]

(* The fork's TAKEOFF_TIMEOUT: the fade after the town's A (none: the town
   is not one Fly goes to), and LANDING_TIMEOUT: the flight and the landing,
   to the overworld at rest. *)
let takeoff_timeout_ms = 10000
let landing_timeout_ms = 30000

(* The overworld before the party opens: the scene Fly must leave. *)
let departure () =
  match
    Effects.await ~timeout_ms:Menu_input.screen_timeout_ms (fun m ->
        Option.is_some (Frlg_readers.Scene_signature.read m))
  with
  | Holds m -> Frlg_readers.Scene_signature.read m
  | Timeout -> None

let faded m =
  (Frlg_readers.Screen_facts.of_measurements m).fade
  <> Screen_state.Fade.No_fade

let fail code detail = Error (Pokemon_engine.Failure.cause code detail)

(* A on the town, the fade watched from the press on: the fly map's fade is
   over in half a second, so a look that starts after it misses it (mg-01
   run 1, 2026-11-23: the settle's looks, 1.4 s apart, saw neither black). *)
let take_off () =
  match Effects.race [ press Wire.A ] ~stop:faded with
  | Stopped _ -> true
  | Finished _ -> (
      match Effects.await ~timeout_ms:takeoff_timeout_ms faded with
      | Holds _ -> true
      | Timeout -> false)

let left_departure before =
  match Effects.read () with
  | Some m -> Frlg_readers.Scene_signature.left ~before m
  | None -> false

(* The fork's landing judge (judge_fly_landing()), looked at until it holds
   or the landing's time is up: the overworld quiet (the talk settle) and the
   screen no longer the departure town's, whose quiet with the bird over it
   comes first. Its facing read has no reader here. *)
let rec judge_landing ~log ~deadline plan before =
  let town = plan.town.Fly_towns.name in
  match
    Scene_readings.settle Talk ~label:("fly to " ^ town) ~battle_ends:false ~log
  with
  | Error _ as e -> e
  | Ok () when left_departure before ->
      log ("Fly: landed in " ^ town ^ ".");
      Ok ()
  | Ok () when Effects.now () > deadline ->
      fail "fly_no_landing"
        (town ^ ": the screen still shows the departure town")
  | Ok () -> judge_landing ~log ~deadline plan before

let fly_from_map ~log plan before =
  ignore (Effects.submit (Fly_towns.cursor_presses plan.town));
  if take_off () then
    judge_landing ~log
      ~deadline:(Effects.now () +. float_of_int landing_timeout_ms)
      plan before
  else fail "fly_no_takeoff" (plan.town.name ^ ": no fade after the town's A")

let fly_steps ~log plan =
  let departure = departure () in
  log
    (Printf.sprintf "Fly with slot %d, menu row %d, to %s (cell %d, %d)."
       plan.slot plan.menu_row plan.town.name plan.town.cell.x plan.town.cell.y);
  match (to_fly_map plan, departure) with
  | exception Menu_input.Action_failed cause -> Error cause
  | (), None -> fail "fly_no_landing" "no screen before the Fly"
  | (), Some before -> fly_from_map ~log plan before

let fly ~log plan =
  Effects.with_probes (Menu_input.probes @ Frlg_readers.Scene_signature.probes)
    (fun () -> fly_steps ~log plan)
