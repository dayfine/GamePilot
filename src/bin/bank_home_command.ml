(* gamepilot ctl [--port N] [--owner LABEL] bank-home plza [--look]

   Banks PLZA's two gifts into Pokémon HOME and saves it
   (Pokemon_home.Home_bank, the lab's plza_claim_and_bank.sh from the BDSPLab
   lab tools, its stages 4 and 5): from the Switch's HOME menu, Pokémon HOME
   opened on Legends: Z-A; the Vivillon (Box 1 slot 2) into the first empty
   slot of HOME box 166, or 167, scanning right to left; the Xerneas (Box 1
   slot 1) into 165, or 164, left to right; saved, closed. [--look] stops on
   the boxes and logs the box number and HOME's box, moving nothing. Through a
   running daemon under the input lease
   (Console_park_command.run_step); the daemon must show the
   whole frame (--viewport native).

   The templates: Pokémon HOME's tile art, the box counter's "/300" and digits
   (pokemon/home/assets/, box-digit-<d>.png for each digit cut so far), and
   PLZA's icon on HOME's game list (games/pokemon/plza/assets/). *)

module H = Pokemon_home.Home_bank

let usage_line =
  "      | bank-home plza [--look]  (Pokémon HOME: PLZA's Vivillon and\n\
  \        Xerneas banked in boxes 166/167 and 165/164, saved, closed)\n"

let assets = "src/pokemon/home/assets/"
let digit_path d = Printf.sprintf "%sbox-digit-%d.png" assets d

let plza_moves : Pokemon_home.Box_moves.t list =
  [
    {
      name = "Vivillon";
      game_col = 1;
      boxes = [ 166; 167 ];
      order = Right_to_left;
    };
    {
      name = "Xerneas";
      game_col = 0;
      boxes = [ 165; 164 ];
      order = Left_to_right;
    };
  ]

let ( let* ) = Result.bind

let read path =
  match Repo_io.Repo_files.locate path with
  | None -> Error ("bank-home: " ^ path ^ " not found above here")
  | Some file -> Ok (In_channel.with_open_bin file In_channel.input_all)

(* The digits cut so far: a missing file is a digit without a template. *)
let digits () =
  List.filter_map
    (fun d ->
      Option.map (fun png -> (d, png)) (Result.to_option (read (digit_path d))))
    (List.init 10 Fun.id)

let templates () =
  let* home_art = read (assets ^ "switch-home-tile.png") in
  let* slash = read (assets ^ "box-counter-slash-300.png") in
  let* game_icon = read "src/games/pokemon/plza/assets/home-game-icon.png" in
  Ok { H.home_art; game_icon; slash; digits = digits () }

let run ~port ~owner mode =
  Result.map
    (fun t ->
      Console_park_command.run_step ~port ~owner ~name:"Bank in HOME"
        (fun ~log ~picture -> H.run ~log ~picture t mode))
    (templates ())

let main ~port ~owner = function
  | [ "plza" ] -> run ~port ~owner (H.Bank plza_moves)
  | [ "plza"; "--look" ] -> run ~port ~owner H.Look
  | _ -> Error "ctl: bank-home takes a game and --look: plza [--look]"
