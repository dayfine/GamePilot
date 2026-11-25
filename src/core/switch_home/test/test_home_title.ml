(* The walk along HOME's tile row to a game's tile (Home_title.find_tile), on
   a scripted row: HOME puts the cursor on the first tile, Right moves it one
   tile on, and the title shows on the game's tile alone. The game first,
   fourth (the lab's console with Pokémon HOME played last, 2026-11-25) and
   eighth is found, the cursor left on it; not among the first eight, the walk
   stops after eight reads and seven Rights. *)

open Switch_home

let walk : Home_title.walk =
  {
    first = { button = Home; hold_ms = 160; cooldown_ms = 960 };
    next = { button = Right; hold_ms = 80; cooldown_ms = 500 };
    tiles = 8;
  }

(* The row, the cursor at [cursor] (no HOME pressed yet: elsewhere), the
   game's tile at [game] (0 the first). *)
let walked game () =
  let cursor = ref None and presses = ref [] and lines = ref [] in
  let press (p : Timed_press.t) =
    presses := Wire.string_of_button p.button :: !presses;
    match p.button with
    | Wire.Home -> cursor := Some 0
    | Wire.Right -> cursor := Option.map succ !cursor
    | _ -> ()
  in
  let steps : Home_title.game_steps =
    {
      title_shows = (fun () -> !cursor = Some game);
      press;
      log = (fun l -> lines := l :: !lines);
    }
  in
  let outcome =
    match Home_title.find_tile steps walk ~name:"Pokémon Legends: Z-A" with
    | Ok k -> Printf.sprintf "tile %d" k
    | Error e -> e
  in
  Printf.sprintf "%s; cursor %s; pressed %s; logged %s" outcome
    (Option.fold ~none:"-" ~some:string_of_int !cursor)
    (String.concat " " (List.rev !presses))
    (String.concat " | " (List.rev !lines))

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "home_title"
    [
      case "the first tile" (walked 0)
        "tile 0; cursor 0; pressed Home; logged Pokémon Legends: Z-A is tile 1.";
      case "the fourth tile, Pokémon HOME first" (walked 3)
        "tile 3; cursor 3; pressed Home Right Right Right; logged Pokémon \
         Legends: Z-A is tile 4.";
      case "the eighth tile" (walked 7)
        "tile 7; cursor 7; pressed Home Right Right Right Right Right Right \
         Right; logged Pokémon Legends: Z-A is tile 8.";
      case "the ninth tile: not found" (walked 8)
        "Pokémon Legends: Z-A's tile is not among the first 8 on HOME; cursor \
         7; pressed Home Right Right Right Right Right Right Right; logged ";
    ]
