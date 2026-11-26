(* Catalog_moves: the gift catalog's Pokémon read into bank-home's moves (the
   shipped gifts.json, and catalogs edited from it), and the program's own
   plan checked (Bank_home_game.check_plan). No fakes: pure conversion, the
   files read from the repo. *)

module C = Plza_gift_catalog.Gift_catalog
module Moves = Plza_bank_home.Catalog_moves
module G = Plza_bank_home.Bank_home_game
module M = Pokemon_home.Box_moves

let case name input expectation = { Table_test.name; input; expectation }

let catalog =
  Result.get_ok
    (Plza_gift_catalog.Gift_catalog_decode.of_json
       (Yojson.Safe.from_file "../../claim_gifts/gifts.json"))

let order_text = function
  | Pokemon_home.Box_view.Left_to_right -> "left_to_right"
  | Right_to_left -> "right_to_left"

let move_text (m : M.t) =
  Printf.sprintf "%s col %d boxes %s %s" m.name m.game_col
    (String.concat "," (List.map string_of_int m.boxes))
    (order_text m.order)

let text = function
  | Ok moves -> String.concat "; " (List.map move_text moves)
  | Error e -> "error: " ^ e

let nth n =
  text (Result.map (fun ms -> [ List.nth ms n ]) (Moves.of_catalog catalog))

(* The catalog with the Xerneas' slot moved to [slot]. *)
let xerneas_at slot =
  List.map
    (fun (g : C.gift) ->
      match g.pokemon with
      | Some p when g.id = "xerneas-30th" ->
          { g with pokemon = Some { p with box_slot = { box = 1; slot } } }
      | _ -> g)
    catalog

let items_only = List.filter (fun (g : C.gift) -> g.pokemon = None) catalog

let plan_check () =
  match Plza_engine.Plan_decode.load "../plans/01-bank-gifts.plan.json" with
  | Error e -> "error: " ^ e
  | Ok plan -> (
      match G.check_plan plan with Ok () -> "ok" | Error e -> "error: " ^ e)

let () =
  Table_test.run "catalog_moves"
    [
      case "the catalog's first Pokémon: Vivillon from slot 2"
        (fun () -> nth 0)
        "Vivillon (Poké Ball Pattern) col 1 boxes 166,167 right_to_left";
      case "the catalog's second Pokémon: Xerneas from slot 1"
        (fun () -> nth 1)
        "Shiny Xerneas (30th anniversary) col 0 boxes 165,164 left_to_right";
      case "items are not moved"
        (fun () ->
          string_of_int (List.length (Result.get_ok (Moves.of_catalog catalog))))
        "2";
      case "a slot past the first row"
        (fun () -> text (Moves.of_catalog (xerneas_at 7)))
        "error: xerneas-30th: Box 1 slot 7 is not in Box 1's first row (1 to 6)";
      case "no Pokémon at all"
        (fun () -> text (Moves.of_catalog items_only))
        "error: the gift catalog has no Pokémon to move";
      case "the program's plan checks" plan_check "ok";
    ]
