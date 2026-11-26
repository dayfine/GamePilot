(* Catalog_moves: the gift catalog's Pokémon read into bank-home's moves (the
   shipped gifts.json, and catalogs edited from it) on a fixed day (no clock
   is read): an expired gift skipped as claim-gifts skips it, any other
   moved; and the program's own plan checked (Bank_home_game.check_plan). No
   fakes: pure conversion, the files read from the repo. *)

module C = Plza_gift_catalog.Gift_catalog
module Moves = Plza_bank_home.Catalog_moves
module G = Plza_bank_home.Bank_home_game
module M = Pokemon_home.Box_moves

let case name input expectation = { Table_test.name; input; expectation }

let catalog =
  Result.get_ok
    (Plza_gift_catalog.Gift_catalog_decode.of_json
       (Yojson.Safe.from_file "../../../gift_catalog/gifts.json"))

let order_text = function
  | Pokemon_home.Box_view.Left_to_right -> "left_to_right"
  | Right_to_left -> "right_to_left"

let move_text (m : M.t) =
  Printf.sprintf "%s col %d boxes %s %s" m.name m.game_col
    (String.concat "," (List.map string_of_int m.boxes))
    (order_text m.order)

let day s = Result.get_ok (C.date_of_string s)

(* A day before every gift's last. *)
let today = day "2026-11-25"

let text = function
  | Ok (t : Moves.t) -> String.concat "; " (List.map move_text t.moves)
  | Error e -> "error: " ^ e

let moves_on d = Moves.of_catalog ~today:(day d) catalog

let skipped_on d =
  match moves_on d with
  | Ok t -> String.concat " " t.skipped
  | Error e -> "error: " ^ e

let nth n =
  text
    (Result.map
       (fun (t : Moves.t) -> { t with moves = [ List.nth t.moves n ] })
       (Moves.of_catalog ~today catalog))

(* The catalog with the Xerneas' slot moved to [slot]. *)
let xerneas_at slot =
  List.map
    (fun (g : C.gift) ->
      match g.pokemon with
      | Some p when g.id = "xerneas-30th" ->
          { g with pokemon = Some { p with box_slot = { box = 1; slot } } }
      | _ -> g)
    catalog

(* The catalog with the Xerneas a HOME gift, which claim-gifts reports "not
   supported" and never claims. *)
let xerneas_by_home =
  List.map
    (fun (g : C.gift) ->
      if g.id = "xerneas-30th" then { g with how = C.Home; code = None } else g)
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
          string_of_int
            (List.length (Result.get_ok (Moves.of_catalog ~today catalog)).moves))
        "2";
      case "a slot past the first row"
        (fun () -> text (Moves.of_catalog ~today (xerneas_at 7)))
        "error: xerneas-30th: Box 1 slot 7 is not in Box 1's first row (1 to 6)";
      case "no Pokémon at all"
        (fun () -> text (Moves.of_catalog ~today items_only))
        "error: the gift catalog has no Pokémon to move";
      case "on the Xerneas' last day: both moved"
        (fun () -> text (moves_on "2027-01-07"))
        "Vivillon (Poké Ball Pattern) col 1 boxes 166,167 right_to_left; Shiny \
         Xerneas (30th anniversary) col 0 boxes 165,164 left_to_right";
      case "the day after: the Xerneas skipped, as claim-gifts skips it"
        (fun () -> text (moves_on "2027-01-08"))
        "Vivillon (Poké Ball Pattern) col 1 boxes 166,167 right_to_left";
      case "the day after: the skip's log line"
        (fun () -> skipped_on "2027-01-08")
        "Skipping xerneas-30th: its last day was 2027-01-07.";
      case "nothing expired: nothing skipped"
        (fun () -> skipped_on "2026-11-25")
        "";
      case
        "a gift claim-gifts cannot claim, not expired: still moved, so its \
         empty slot fails the bank"
        (fun () -> text (Moves.of_catalog ~today xerneas_by_home))
        "Vivillon (Poké Ball Pattern) col 1 boxes 166,167 right_to_left; Shiny \
         Xerneas (30th anniversary) col 0 boxes 165,164 left_to_right";
      case "every Pokémon expired: nothing to move"
        (fun () -> text (moves_on "2027-02-26"))
        "error: every Pokémon gift of the catalog has expired, nothing to \
         move: Skipping vivillon-poke-ball: its last day was 2027-02-25. \
         Skipping xerneas-30th: its last day was 2027-01-07.";
      case "the program's plan checks" plan_check "ok";
    ]
