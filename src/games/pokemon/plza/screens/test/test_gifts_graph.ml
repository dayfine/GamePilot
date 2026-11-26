(* Plza_screens.Gifts: structural graph check (Screen_graph.Graph.check),
   shortest paths, and fixture frame reads against recorded console B captures
   (../../readers/test/fixtures/gifts/gifts.probes.jsonl). No fakes. *)

module G = Screen_graph.Graph
module Gifts = Plza_screens.Gifts

let captures =
  Wire.read_image_probes "../../readers/test/fixtures/gifts/gifts.probes.jsonl"

let frame path : Wire.frame =
  { seq = 1; t_ms = 0.; probes = List.assoc path captures }

let read_fixture path () =
  match Gifts.read (frame path) with
  | [] -> "unread"
  | cs -> String.concat "," (List.map Gifts.show cs)

let check_graph () =
  match G.check Gifts.walk_graph with Ok () -> "ok" | Error e -> "err: " ^ e

let path_to_home from () =
  match G.path Gifts.walk_graph ~from ~at:Gifts.is_main_menu with
  | None -> "none"
  | Some es ->
      String.concat " -> "
        (List.map (fun (e : _ G.edge) -> Gifts.show e.leads_to) es)

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "plza_gifts_graph"
    [
      case "graph passes structural check" check_graph "ok";
      case "path from Card to main menu" (path_to_home Card)
        "Gift_list(0) -> Stop_receiving(Yes) -> Gift_menu -> Disconnect(Yes) \
         -> Message -> Main_menu(5)";
      case "path from Stop_receiving(No) to main menu"
        (path_to_home (Stop_receiving No))
        "Stop_receiving(Yes) -> Gift_menu -> Disconnect(Yes) -> Message -> \
         Main_menu(5)";
      case "path from Disconnect(No) to main menu"
        (path_to_home (Disconnect No))
        "Disconnect(Yes) -> Message -> Main_menu(5)";
      case "path from Gift_list(0) to Card is none (claim is Acts)"
        (fun () ->
          match
            G.path Gifts.walk_graph ~from:(Gift_list 0)
              ~at:(G.exactly Gifts.Card)
          with
          | None -> "none"
          | Some _ -> "found")
        "none";
      case "reads main menu fixture"
        (read_fixture "./tutorial-cards/it-menu-no-card.jpg")
        "Main_menu(0)";
      case "reads gift list fixture"
        (read_fixture "./mystery-gift/gift-list-cursor-on-1.png")
        "Gift_list(0)";
      case "reads English card fixture"
        (read_fixture "./mystery-gift/card-vivillon.png")
        "Card";
      case "reads Japanese card fixture"
        (read_fixture "./mystery-gift/card-vivillon-ja.png")
        "Card";
      case "reads item card fixture"
        (read_fixture "./mystery-gift/card-item-ja-360p.png")
        "Card";
      case "reads stop receiving Yes fixture"
        (read_fixture "./mystery-gift/gift-list-ja-stop-receiving-yes-360p.png")
        "Stop_receiving(Yes)";
      case "reads stop receiving No fixture"
        (read_fixture "./mystery-gift/gift-list-ja-stop-receiving-no-360p.png")
        "Stop_receiving(No)";
      case "reads gift menu fixture"
        (read_fixture "./mystery-gift/gift-menu-ja-360p.png")
        "Gift_menu";
      case "reads question over gift menu fixture"
        (read_fixture "./mystery-gift/gift-menu-ja-report-question-360p.png")
        "Disconnect(Yes)";
      case "reads message fixture"
        (read_fixture "./mystery-gift/gift-menu-ja-connected-message-360p.png")
        "Message";
      case "white fade reads as unread"
        (read_fixture "./mystery-gift/claim-white-fade.png")
        "unread";
    ]
