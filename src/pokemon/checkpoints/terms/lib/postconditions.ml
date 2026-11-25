type party =
  | Party_in_order of string list
  | Party_includes of { members : string list; slots : slot list }

and slot = { slot : int; species : string }

type bag_count = { bag_item : string; count : Engine_promise.Count.t }
type knows = { species : string; moves : string list }
type level = { species : string; min : int }

type t = {
  position : Pose.grid option;
  party : party option;
  items : bag_count list;
  coins : Engine_promise.Count.t option;
  money : Engine_promise.Money.t option;
  flags : string list;
  knows : knows list;
  levels : level list;
  marks : string list option;
}

let none =
  {
    position = None;
    party = None;
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let checked_at_end p =
  p.party <> None || p.items <> [] || p.coins <> None || p.money <> None
  || p.flags <> []

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
      some (fun g -> "position " ^ Pose.grid_to_string g) p.position;
      party_text p.party;
      List.map bag_count_text p.items;
      some (fun c -> "coins " ^ count_text c) p.coins;
      some Engine_promise.Money.text p.money;
      (if p.flags = [] then [] else [ "flags " ^ list p.flags ]);
      List.map knows_text p.knows;
      List.map level_text p.levels;
      some (fun m -> "marks " ^ list m) p.marks;
    ]
