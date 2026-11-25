module T = Switch_home.Timed_press
module G = Switch_home.Game_entry
module M = Home_menus

let ( let* ) = Result.bind
let probes ~game_icon = M.probes ~game_icon
let read_ms = 3000

let find_tile ~picture art_png =
  let art = Effects.upload_template art_png in
  let probes =
    Switch_home.Home_screen.probes ~picture Home_tile.tile_color
    @ Home_tile.probes art
  in
  Effects.with_probes probes (fun () ->
      match
        Effects.await ~timeout_ms:read_ms (fun m -> Home_tile.tile m <> None)
      with
      | Holds m -> Option.to_result ~none:"" (Home_tile.tile m)
      | Timeout ->
          Error "Pokémon HOME's tile is not among the first four on HOME")

let title_a : T.t = { button = A; hold_ms = 100; cooldown_ms = 3000 }
let menu_rounds = 30

let to_main_menu ~log =
  let rec go n =
    match Effects.await ~timeout_ms:read_ms M.main_menu with
    | Holds _ ->
        log "Pokémon HOME's main menu.";
        Ok ()
    | Timeout when n >= menu_rounds ->
        Error "Pokémon HOME's main menu did not show in 90 s"
    | Timeout ->
        let banner =
          Option.fold ~none:M.No_banner ~some:M.banner (Effects.read ())
        in
        if banner = M.No_banner then T.press title_a;
        go (n + 1)
  in
  go 0

let open_list : T.t = { button = A; hold_ms = 100; cooldown_ms = 3500 }
let list_ms = 10_000
let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 400 }

let steps n (forward, back) =
  T.times (abs n) (dpad (if n > 0 then forward else back))

let await_list () =
  match
    Effects.await ~timeout_ms:list_ms (fun m -> M.cursor_tile m <> None)
  with
  | Holds m -> Option.to_result ~none:"" (M.cursor_tile m)
  | Timeout -> Error "Pokémon HOME's game list did not show"

let tile_text (t : M.tile) =
  Printf.sprintf "row %d, column %d" (t.row + 1) (t.col + 1)

let no_icon m =
  Printf.sprintf "the game's icon is on no tile of HOME's game list (scores %s)"
    (String.concat " " (List.map (Printf.sprintf "%.3f") (M.icon_scores m)))

let game_tile () =
  match Effects.read () with
  | Some m -> Option.to_result ~none:(no_icon m) (M.game_tile m)
  | None -> Error "no frame"

let to_game ~log =
  let* cursor = await_list () in
  let* (game : M.tile) = game_tile () in
  T.press_all
    (steps (game.row - cursor.row) (Down, Up)
    @ steps (game.col - cursor.col) (Right, Left));
  match
    Effects.await ~timeout_ms:read_ms (fun m -> M.cursor_tile m = Some game)
  with
  | Holds _ ->
      log ("The game's tile: " ^ tile_text game ^ ".");
      Ok ()
  | Timeout ->
      Error ("the cursor did not reach the game's tile, " ^ tile_text game)

let connect : T.t list =
  [
    { button = A; hold_ms = 100; cooldown_ms = 2000 };
    { button = A; hold_ms = 100; cooldown_ms = 8000 };
  ]

let boxes_ms = 30_000

let to_boxes ~log ~picture ~home_art ~game_icon =
  let* () = G.close_game ~log ~picture Home_tile.tile_color in
  let* tile = find_tile ~picture home_art in
  log (Printf.sprintf "Pokémon HOME is tile %d." (tile + 1));
  let* () =
    G.start_game ~log ~picture ~game_slot:(tile + 1) ~user_slot:0
      Home_tile.tile_color
  in
  Effects.with_probes (probes ~game_icon) (fun () ->
      let* () = to_main_menu ~log in
      T.press open_list;
      let* () = to_game ~log in
      T.press_all connect;
      match Effects.await ~timeout_ms:boxes_ms Box_view.shown with
      | Holds _ -> Ok (log "The boxes.")
      | Timeout -> Error "the box screen did not show after connecting the game")
