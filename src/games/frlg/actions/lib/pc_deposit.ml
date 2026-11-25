open Frlg_readers
module Steps = Pc_deposit_steps
module Text = Frlg_text

let first_presses = 80
let more_presses = 40
let max_presses n = first_presses + (more_presses * max 0 (n - 1))
let overworld_confirm_ms = 800
let box_full = "The BOX is full."
let remove_mail = "Please remove the MAIL."
let messages = [ "Deposit in which BOX?"; box_full; remove_mail ]

(* A deposit's first row is STORE, a withdraw's WITHDRAW. *)
let mon_menu_rows =
  [ "STORE"; "WITHDRAW"; "SUMMARY"; "MARK"; "RELEASE"; "CANCEL" ]

let menu_rows =
  [
    "SOMEONE'S PC";
    "BILL'S PC";
    "WITHDRAW POKéMON";
    "DEPOSIT POKéMON";
    "MOVE POKéMON";
    "MOVE ITEMS";
    "SEE YA!";
    "LOG OFF";
  ]

let text ?ink line candidates =
  match Text.Line_reading.read ?ink (Text_data.glyphs ()) line candidates with
  | Read { text; _ } -> Some text
  | No_match _ -> None

let species_shown () =
  let names = Text_data.species_names () in
  Option.bind
    (text ~ink:Text.Line_reading.light_ink Text.Text_lines.pc_data_species
       (List.map (fun (_, n) -> "/" ^ n) names))
    (fun shown ->
      Option.map fst (List.find_opt (fun (_, n) -> "/" ^ n = shown) names))

let label (v : Pc_screen.view) =
  match (v.screen, v.cursor) with
  | (Pc_list | Storage_menu), Some row ->
      text (Text.Text_lines.pc_menu_row row) menu_rows
  | Mon_menu, Some row ->
      text (Text.Text_lines.pc_mon_menu_row row) mon_menu_rows
  | _ -> None

let wait ms =
  ignore (Effects.submit [ Wire.Wait { wait_ms = ms } ] : Wire.batch_done)

let frame () =
  match Effects.read () with
  | Some m -> Pc_screen.read m
  | None -> { screen = Other; cursor = None }

(* A frame between two menus can read as the overworld: a second look. *)
let view () =
  let v = frame () in
  if v.screen = Overworld then (
    wait overworld_confirm_ms;
    frame ())
  else v

let message () = text Text.Text_lines.pc_message messages

let look () : Steps.look =
  let view = view () in
  {
    view;
    label = label view;
    species = (if view.screen = Party_panel then species_shown () else None);
    box_full = view.screen = Box_chooser && message () = Some box_full;
    remove_mail = view.screen = Party_panel && message () = Some remove_mail;
  }

(* The fork's ConsolePcStorageActions::press(). *)
let hold_ms = 160
let button_cooldown_ms = 640
let dpad_cooldown_ms = 320
let wait_ms = 500

let press (p : Steps.press) =
  let button b = Menu_input.hold ~hold_ms ~cooldown_ms:button_cooldown_ms b in
  let dpad b = Menu_input.hold ~hold_ms ~cooldown_ms:dpad_cooldown_ms b in
  let commands =
    match p with
    | A -> [ button Wire.A ]
    | B -> [ button Wire.B ]
    | Up -> [ dpad Wire.Up ]
    | Down -> [ dpad Wire.Down ]
    | Left -> [ dpad Wire.Left ]
    | Right -> [ dpad Wire.Right ]
    | Wait | Done | Fail _ -> [ Wire.Wait { wait_ms } ]
  in
  ignore (Effects.submit commands : Wire.batch_done)

let describe (l : Steps.look) =
  Printf.sprintf "%s (cursor %s%s%s)"
    (Pc_screen.screen_name l.view.screen)
    (Option.fold ~none:"-" ~some:string_of_int l.view.cursor)
    (Option.fold ~none:"" ~some:(fun s -> ", " ^ s) l.label)
    (Option.fold ~none:"" ~some:(fun s -> ", " ^ s) l.species)

let rec run ~log steps left =
  if left = 0 then
    Menu_input.fail "pc_deposit" "not back on the overworld in time"
  else
    let l = look () in
    let steps, p = Steps.next steps l in
    log (Printf.sprintf "PC: %s: %s." (describe l) (Steps.press_to_string p));
    match p with
    | Done -> ()
    | Fail why ->
        Menu_input.fail "pc_deposit"
          (Pc_screen.screen_name l.view.screen ^ ": " ^ why)
    | p ->
        press p;
        run ~log steps (left - 1)

let deposit ~log species =
  Effects.with_probes Pc_screen.probes (fun () ->
      run ~log (Steps.start species) (max_presses (List.length species)));
  log ("PC: deposited " ^ String.concat ", " species ^ ".")
