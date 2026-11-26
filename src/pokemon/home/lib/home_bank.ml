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

type on_failure = Stop_open | Quit_discard | Save_partial
type deposit = { moves : Box_moves.t list; on_failure : on_failure }
type mode = Look | Bank of deposit

type game_steps = {
  move : Box_moves.t -> (unit, Box_moves.move_error) result;
  save : unit -> (unit, string) result;
  close : unit -> (unit, string) result;
  log : string -> unit;
}

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

let close_with steps detail =
  let* () = steps.close () in
  Error detail

let save_partial_and_close steps ~moved ~total (err : Box_moves.move_error) =
  if err.holding then
    Error
      (err.message
     ^ "; cursor may hold a Pokémon, Pokémon HOME left open unsaved")
  else if moved = 0 then
    close_with steps (err.message ^ "; nothing moved, Pokémon HOME closed")
  else
    let* () = steps.save () in
    close_with steps
      (Printf.sprintf "saved %d of %d Pokémon before failure: %s" moved total
         err.message)

let finish_failed steps ~on_failure ~moved ~total (err : Box_moves.move_error) =
  match on_failure with
  | Stop_open -> Error err.message
  | Quit_discard ->
      close_with steps (err.message ^ "; Pokémon HOME closed, unsaved")
  | Save_partial -> save_partial_and_close steps ~moved ~total err

let run_deposit steps { moves; on_failure } =
  let total = List.length moves in
  let rec loop moved = function
    | [] ->
        let* () = if moved > 0 then steps.save () else Ok () in
        steps.close ()
    | move :: rest -> (
        match steps.move move with
        | Ok () -> loop (moved + 1) rest
        | Error err -> finish_failed steps ~on_failure ~moved ~total err)
  in
  loop 0 moves

let no_digits =
  Error
    "a box-number digit has no template yet; nothing moved, Pokémon HOME left \
     open"

let live_game_steps ~log ~picture : game_steps =
  {
    move = Box_moves.run ~log;
    save = (fun () -> save ~log);
    close =
      (fun () ->
        log "Closing Pokémon HOME.";
        Switch_home.Game_entry.close_game ~log ~picture Home_tile.tile_color);
    log;
  }

let bank_all ~log ~picture templates deposit =
  if B.complete templates then
    Effects.with_probes (Box_moves.cursor_probes deposit.moves) (fun () ->
        run_deposit (live_game_steps ~log ~picture) deposit)
  else no_digits

let on_boxes ~log ~picture templates = function
  | Look -> look ~log
  | Bank deposit -> bank_all ~log ~picture templates deposit

let launch_and_act ~log ~picture (t : templates) mode =
  let box_templates = upload t in
  let game_icon = Effects.upload_template t.game_icon in
  let on_menus () = on_boxes ~log ~picture box_templates mode in
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
  else launch_and_act ~log ~picture t mode
