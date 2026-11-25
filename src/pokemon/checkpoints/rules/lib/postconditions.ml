type party =
  | Party_in_order of string list
  | Party_includes of { members : string list; slots : slot list }

and slot = { slot : int; species : string }

type bag_count = { bag_item : string; count : Engine_postcondition.Count.t }
type knows = { species : string; moves : string list }
type level = { species : string; min : int }

type t = {
  position : Pose.grid option;
  party : party option;
  items : bag_count list;
  coins : Engine_postcondition.Count.t option;
  caught : Engine_postcondition.Count.t option;
  money : Engine_postcondition.Money.t option;
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
    caught = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let stated = Option.value ~default:none

let at_end p =
  if
    p.party <> None || p.items <> [] || p.coins <> None || p.caught <> None
    || p.money <> None || p.flags <> []
  then Some p
  else None
