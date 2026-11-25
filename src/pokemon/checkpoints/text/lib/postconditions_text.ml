open Pokemon_terms
open Postconditions

let list = String.concat ", "
let count_text = Engine_promise.Count.text

let slot_text ({ slot; species } : slot) =
  Printf.sprintf "%s in slot %d" species slot

let party_text : party option -> string list = function
  | Some (Party_in_order l) -> [ "party in order " ^ list l ]
  | Some (Party_includes { members; slots }) ->
      ("party includes " ^ list members) :: List.map slot_text slots
  | None -> []

let bag_count_text ({ bag_item; count } : bag_count) =
  Printf.sprintf "item %s %s" bag_item (count_text count)

let knows_text ({ species; moves } : knows) =
  Printf.sprintf "%s knows %s" species (list moves)

let level_text ({ species; min } : level) =
  Printf.sprintf "%s at least Lv %d" species min

let some f = Option.fold ~none:[] ~some:(fun x -> [ f x ])

let text p =
  List.concat
    [
      some (fun g -> "position " ^ Pose_text.grid g) p.position;
      party_text p.party;
      List.map bag_count_text p.items;
      some (fun c -> "coins " ^ count_text c) p.coins;
      some Engine_promise.Money.text p.money;
      (if p.flags = [] then [] else [ "flags " ^ list p.flags ]);
      List.map knows_text p.knows;
      List.map level_text p.levels;
      some (fun m -> "marks " ^ list m) p.marks;
    ]
