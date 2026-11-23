type outcome =
  | Passed of { opened_ms : float; closed_ms : float }
  | Did_not_open
  | Did_not_close

let home () =
  match Sys.getenv_opt "HOME" with
  | Some h -> h
  | None -> Option.value (Sys.getenv_opt "USERPROFILE") ~default:"."

let default_state =
  List.fold_left Filename.concat (home ())
    [ "FRLGLab"; "mgba"; "gamepilot"; "states"; "overworld.ss" ]

let timeout_ms = 3000

let press button =
  Wire.Press { buttons = [ button ]; hold_ms = 100; cooldown_ms = 100 }

(* Presses [button], then waits for [pred]; returns ms from batch_done to the
   frame where it held. *)
let press_until button pred =
  let done_ = Effects.submit [ press button ] in
  match Effects.await ~timeout_ms pred with
  | Effects.Holds m -> Some (Float.max 0. (m.t_ms -. done_.t_ms))
  | Effects.Timeout -> None

let menu_open = Frlg_readers.Start_menu.start_menu_open
let menu_closed m = not (menu_open m)

let run ~state () =
  ignore (Effects.load_state state : int);
  ignore (Effects.subscribe [ Frlg_readers.Start_menu.probe ] : string list);
  match press_until Wire.Start menu_open with
  | None -> Did_not_open
  | Some opened_ms -> (
      match press_until Wire.B menu_closed with
      | None -> Did_not_close
      | Some closed_ms -> Passed { opened_ms; closed_ms })

let describe = function
  | Passed { opened_ms; closed_ms } ->
      Printf.sprintf
        "start_menu_poc: PASS (open %.0f ms, close %.0f ms after batch_done)"
        opened_ms closed_ms
  | Did_not_open ->
      Printf.sprintf "start_menu_poc: FAIL menu did not open within %d ms"
        timeout_ms
  | Did_not_close ->
      Printf.sprintf "start_menu_poc: FAIL menu did not close within %d ms"
        timeout_ms
