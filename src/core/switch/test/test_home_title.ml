(* The walk along HOME's tile row to a game's tile (Home_title.find_tile), on
   a scripted row: HOME puts the cursor on the first tile, Right moves it one
   tile on, and the title shows on the game's tile alone. The game first,
   fourth (the lab's console with Pokémon HOME played last, 2026-11-25) and
   eighth is found, the cursor left on it; not among the first eight, the walk
   stops after eight reads and seven Rights. *)

open Switch

let walk : Home_title.walk =
  {
    first = { button = Home; hold_ms = 160; cooldown_ms = 960 };
    next = { button = Right; hold_ms = 80; cooldown_ms = 500 };
    tiles = 8;
  }

type walk_end = {
  outcome : string;
  cursor : string;
  pressed : string;
  logged : string;
}

(* The row, the cursor at [cursor] (no HOME pressed yet: elsewhere), the
   game's tile at [game] (0 the first); [part] picks the one fact a case
   checks. *)
let walked part game () =
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
  part
    {
      outcome;
      cursor = Option.fold ~none:"-" ~some:string_of_int !cursor;
      pressed = String.concat " " (List.rev !presses);
      logged = String.concat " | " (List.rev !lines);
    }

let outcome e = e.outcome
let cursor e = e.cursor
let pressed e = e.pressed
let logged e = e.logged
let case name input expectation : Table_test.case = { name; input; expectation }
let sevenfold_right = "Home Right Right Right Right Right Right Right"

let () =
  Table_test.run "home_title"
    [
      case "the first tile: found" (walked outcome 0) "tile 0";
      case "the first tile: the cursor left on it" (walked cursor 0) "0";
      case "the first tile: Home alone pressed" (walked pressed 0) "Home";
      case "the first tile: logged" (walked logged 0)
        "Pokémon Legends: Z-A is tile 1.";
      case "the fourth tile, Pokémon HOME first: found" (walked outcome 3)
        "tile 3";
      case "the fourth tile: three Rights" (walked pressed 3)
        "Home Right Right Right";
      case "the eighth tile: found" (walked outcome 7) "tile 7";
      case "the eighth tile: seven Rights" (walked pressed 7) sevenfold_right;
      case "the ninth tile: not found" (walked outcome 8)
        "Pokémon Legends: Z-A's tile is not among the first 8 on HOME";
      case "the ninth tile: the cursor stops on the eighth" (walked cursor 8)
        "7";
      case "the ninth tile: seven Rights, no more" (walked pressed 8)
        sevenfold_right;
      case "the ninth tile: nothing logged" (walked logged 8) "";
    ]
