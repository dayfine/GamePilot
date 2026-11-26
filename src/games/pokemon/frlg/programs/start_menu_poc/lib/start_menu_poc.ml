module Menu_panel = Menu_panel

type outcome =
  | Passed of { opened_ms : float; closed_ms : float }
  | Did_not_open
  | Did_not_close

let default_state =
  Filename.concat
    (Repo_io.Repo_files.data_dir "GAMEPILOT_STATES" "states")
    "overworld.ss"

let timeout_ms = 3000
let press_hold_ms = 100
let press_cooldown_ms = 100

let press button =
  Wire.press ~hold_ms:press_hold_ms ~cooldown_ms:press_cooldown_ms [ button ]

(* Presses [button], then waits for [pred]; returns ms from batch_done to the
   frame where it held. *)
let press_until button pred =
  let done_ = Effects.submit [ press button ] in
  match Effects.await ~timeout_ms pred with
  | Effects.Holds m -> Some (Float.max 0. (m.t_ms -. done_.t_ms))
  | Effects.Timeout -> None

let menu_open = Menu_panel.start_menu_open
let menu_closed m = not (menu_open m)

let run ?state () =
  Option.iter (fun s -> ignore (Effects.load_state s : int)) state;
  ignore (Effects.subscribe [ Menu_panel.probe ] : string list);
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
