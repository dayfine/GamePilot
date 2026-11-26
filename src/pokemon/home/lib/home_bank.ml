module T = Switch_home.Timed_press
module B = Box_view
module M = Home_menus

let ( let* ) = Result.bind

type templates = {
  home_art : string;
  home_title : string;
  game_icon : string;
  slash : string;
  digits : (int * string) list;
}

type mode = Look | Bank of Box_moves.t list

let upload (t : templates) : B.templates =
  {
    slash = Effects.upload_template t.slash;
    digits =
      List.map (fun (d, png) -> (d, Effects.upload_template png)) t.digits;
  }

let row_text m row =
  String.init B.columns (fun col ->
      if B.empty m { pane = Home_box; row; col } then '.' else 'x')

let pane_text m = String.concat "/" (List.init B.slot_rows (row_text m))

let look ~log =
  match Effects.read () with
  | None -> Error "no frame"
  | Some m ->
      log ("Box counter: " ^ B.counter_to_string m);
      log
        ("HOME box "
        ^ Option.fold ~none:"unread" ~some:string_of_int (B.number m)
        ^ ": " ^ pane_text m);
      log
        "Stopped on the boxes; nothing moved. Close Pokémon HOME without \
         saving (HOME, X).";
      Ok ()

let digits = 10

let missing_digits (t : B.templates) =
  List.filter
    (fun d -> not (List.mem_assoc d t.digits))
    (List.init digits Fun.id)

let save_and_quit : T.t list =
  [
    { button = Start; hold_ms = 100; cooldown_ms = 1500 };
    { button = A; hold_ms = 100; cooldown_ms = 500 };
  ]

let saving_ms = 10_000
let saved_ms = 60_000
let dismiss : T.t = { button = A; hold_ms = 100; cooldown_ms = 3500 }

let saved ~log =
  log "Saving.";
  match
    Effects.await ~timeout_ms:saved_ms (fun m ->
        M.banner m = M.One_line || M.main_menu m)
  with
  | Timeout ->
      Error
        "Pokémon HOME showed neither the saved banner nor its main menu in 60 \
         s; left open"
  | Holds m ->
      if not (M.main_menu m) then T.press dismiss;
      Ok (log "Saved.")

let save ~log =
  T.press_all save_and_quit;
  match
    Effects.await ~timeout_ms:saving_ms (fun m -> M.banner m = M.Two_lines)
  with
  | Timeout ->
      Error
        "Pokémon HOME's saving banner did not show; Pokémon HOME left open, \
         unsaved"
  | Holds _ -> saved ~log

let bank ~log moves =
  let* () =
    List.fold_left
      (fun acc move -> Result.bind acc (fun () -> Box_moves.run ~log move))
      (Ok ()) moves
  in
  save ~log

let no_digits missing =
  Error
    (Printf.sprintf
       "no template yet for box-number digits %s; nothing moved, Pokémon HOME \
        left open"
       (String.concat ", " (List.map string_of_int missing)))

let bank_all ~log templates moves =
  match missing_digits templates with
  | [] ->
      Effects.with_probes (Box_moves.cursor_probes moves) (fun () ->
          bank ~log moves)
  | missing -> no_digits missing

let on_boxes ~log templates = function
  | Look -> look ~log
  | Bank moves -> bank_all ~log templates moves

let launch_and_act ~log ~picture (t : templates) mode =
  let box_templates = upload t in
  let game_icon = Effects.upload_template t.game_icon in
  let on_menus () = on_boxes ~log box_templates mode in
  Effects.with_probes (B.probes box_templates) (fun () ->
      let* () =
        Home_launch.to_boxes ~log ~picture ~home_art:t.home_art
          ~home_title:t.home_title ~game_icon
      in
      Effects.with_probes (M.probes ~game_icon) on_menus)

let not_native =
  "Pokémon HOME is read on the whole frame: run the daemon with --viewport \
   native"

let run ~log ~picture (t : templates) mode =
  if not (Switch_home.Picture_box.native picture) then Error not_native
  else
    let* () = launch_and_act ~log ~picture t mode in
    match mode with
    | Look -> Ok ()
    | Bank _ ->
        log "Closing Pokémon HOME.";
        Switch_home.Game_entry.close_game ~log ~picture Home_tile.tile_color
