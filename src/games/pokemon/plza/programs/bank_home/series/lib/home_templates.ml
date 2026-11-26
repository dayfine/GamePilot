let home_assets = "src/pokemon/home/assets/"
let plza_assets = "src/games/pokemon/plza/assets/"
let digit_path d = Printf.sprintf "%sbox-digit-%d.png" home_assets d
let ( let* ) = Result.bind

(* 0 to 9. *)
let digit_count = 10

let read path =
  match Repo_io.Repo_files.locate path with
  | None -> Error (path ^ ": not found from here: run in the repo")
  | Some file -> Ok (In_channel.with_open_bin file In_channel.input_all)

let digits () =
  List.filter_map
    (fun d ->
      Option.map (fun png -> (d, png)) (Result.to_option (read (digit_path d))))
    (List.init digit_count Fun.id)

let load () : (Plza_bank_home.Bank_home_game.templates, string) result =
  let* home_art = read (home_assets ^ "switch-home-tile.png") in
  let* home_title = read (home_assets ^ "switch-home-title-pokemon-home.png") in
  let* slash = read (home_assets ^ "box-counter-slash-300.png") in
  let* game_icon = read (plza_assets ^ "home-game-icon.png") in
  let* plza_title = read Plza_readers.Switch_home_tile.title_template in
  Ok
    {
      Plza_bank_home.Bank_home_game.home =
        { home_art; home_title; game_icon; slash; digits = digits () };
      plza_title;
    }
