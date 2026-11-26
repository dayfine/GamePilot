module Postconditions = Pokemon_engine.Postconditions
open Need

let reads_card =
  List.exists (function
    | Badges_at_least _ | Badges _ | Badge _ | Hall_of_fame -> true
    | _ -> false)

(* An item or the money named only so that it is read (to_read). *)
let any_count bag_item =
  { Postconditions.bag_item; count = Engine_postcondition.Count.Exactly 0 }

let any_money = Engine_postcondition.Money.Range { min = 0; max = 0 }

let reads_party = function
  | Party_in_order _ | Party_includes _ | Member _ | No_mail _ | Knows_move _ ->
      true
  | _ -> false

let to_read needs : Postconditions.t =
  let party = List.exists reads_party needs
  and marks =
    List.exists
      (function No_mail _ | Holding_no_mail _ -> true | _ -> false)
      needs
  and money =
    List.exists
      (function Money_at_least _ | Money_between _ -> true | _ -> false)
      needs
  and caught =
    List.exists (function Caught_at_least _ -> true | _ -> false) needs
  in
  let items =
    List.sort_uniq Stdlib.compare
      (List.filter_map
         (function
           | Item_at_least { item; _ } | Item_exactly { item; _ } -> Some item
           | _ -> None)
         needs)
  in
  {
    position = None;
    party =
      (if party then
         Some (Postconditions.Party_includes { members = []; slots = [] })
       else None);
    items = List.map any_count items;
    coins = None;
    caught =
      (if caught then Some (Engine_postcondition.Count.At_least 0) else None);
    money = (if money then Some any_money else None);
    flags = [];
    knows = [];
    levels = [];
    marks = (if marks then Some [] else None);
  }
