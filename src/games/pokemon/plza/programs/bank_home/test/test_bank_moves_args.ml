(* Bank_moves_args: a bank_in_home event's args read into moves, and the
   program's own plan checked (Bank_home_game.check_plan). No fakes: pure
   decoding, and the plan file read from ../plans. *)

module A = Plza_bank_home.Bank_moves_args
module G = Plza_bank_home.Bank_home_game
module M = Pokemon_home.Box_moves

let case name input expectation = { Table_test.name; input; expectation }

let args text =
  match Yojson.Safe.from_string text with `Assoc obj -> obj | _ -> []

let vivillon =
  {|{"gift": "Vivillon", "box_slot": 2, "home_boxes": [166, 167], "scan": "right_to_left"}|}

let xerneas =
  {|{"gift": "Xerneas", "box_slot": 1, "home_boxes": [165, 164], "scan": "left_to_right"}|}

(* An Eevee move with these fields' values, as JSON. *)
let eevee ~slot ~boxes ~scan =
  Printf.sprintf
    {|{"gift": "Eevee", "box_slot": %d, "home_boxes": [%s], "scan": "%s"}|} slot
    boxes scan

let moves_args moves = args ({|{"moves": [|} ^ String.concat ", " moves ^ "]}")

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

let decoded moves = text (A.of_args (moves_args moves))
let plan_file = "../plans/01-bank-gifts.plan.json"

let plan_check () =
  match Plza_engine.Plan_decode.load plan_file with
  | Error e -> "error: " ^ e
  | Ok plan -> (
      match G.check_plan plan with Ok () -> "ok" | Error e -> "error: " ^ e)

let () =
  Table_test.run "bank_moves_args"
    [
      case "a move: its slot 1-based, its boxes and scan"
        (fun () -> decoded [ vivillon ])
        "Vivillon col 1 boxes 166,167 right_to_left";
      case "moves keep the plan's order"
        (fun () -> decoded [ xerneas; vivillon ])
        "Xerneas col 0 boxes 165,164 left_to_right; Vivillon col 1 boxes \
         166,167 right_to_left";
      case "no move" (fun () -> decoded []) "error: moves: no move";
      case "an arg other than moves"
        (fun () -> text (A.of_args (args {|{"moves": [], "save": true}|})))
        "error: save is not a field of bank_in_home's args (moves)";
      case "a box slot past the first row"
        (fun () -> decoded [ eevee ~slot:7 ~boxes:"1" ~scan:"left_to_right" ])
        "error: moves[0].box_slot is 1 to 6 (Box 1's first row), not 7";
      case "a scan order it does not know"
        (fun () -> decoded [ eevee ~slot:1 ~boxes:"1" ~scan:"up" ])
        "error: moves[0].scan is left_to_right or right_to_left, not up";
      case "a HOME box past the last"
        (fun () -> decoded [ eevee ~slot:1 ~boxes:"301" ~scan:"left_to_right" ])
        "error: Eevee's home_boxes: HOME box 301 is not 1 to 300";
      case "no HOME box"
        (fun () -> decoded [ eevee ~slot:1 ~boxes:"" ~scan:"left_to_right" ])
        "error: Eevee's home_boxes: no HOME box";
      case "two moves from one slot"
        (fun () ->
          decoded [ vivillon; eevee ~slot:2 ~boxes:"1" ~scan:"left_to_right" ])
        "error: two moves of box_slot 2";
      case "the program's plan checks" plan_check "ok";
    ]
