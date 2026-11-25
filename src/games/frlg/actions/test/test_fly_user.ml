(* Fly's user: FLY's row on a member's menu from the moves it knows, and the
   first member that knows Fly. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }

let row moves () =
  Option.fold ~none:"none" ~some:string_of_int (Fly_user.menu_row moves)

let user party () =
  match Fly_user.first party with
  | Some { slot; menu_row } -> Printf.sprintf "slot %d, row %d" slot menu_row
  | None -> "none"

let () =
  Table_test.run "fly_user"
    [
      case "Fly the only field move: the row after SUMMARY"
        (row [ "fly"; "gust"; "quick-attack"; "sand-attack" ])
        "2";
      case "a field move before it in move order comes first"
        (row [ "cut"; "fly"; "gust" ])
        "3";
      case "the menu follows move order, not the field moves' order"
        (row [ "fly"; "cut" ])
        "2";
      case "Teleport and Sweet Scent are field moves too"
        (row [ "teleport"; "sweet-scent"; "fly" ])
        "4";
      case "no Fly" (row [ "surf"; "strength" ]) "none";
      case "the first member that knows Fly"
        (user
           [
             [ "surf"; "strength"; "blizzard"; "bite" ];
             [ "cut"; "absorb" ];
             [ "fly"; "gust" ];
             [ "fly" ];
           ])
        "slot 3, row 2";
      case "nobody knows Fly" (user [ [ "surf" ]; [ "cut" ] ]) "none";
    ]
