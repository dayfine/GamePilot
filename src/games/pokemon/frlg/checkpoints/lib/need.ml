module Postconditions = Pokemon_engine.Postconditions

type t =
  | Party_in_order of string list
  | Party_includes of {
      members : string list;
      slots : Postconditions.slot list;
    }
  | Member of { species : string; for_ : string }
  | No_mail of { species : string; for_ : string }
  | Holding_no_mail of { for_ : string }
  | Knows_move of { move : string; for_ : string }
  | Badge of { badge : string; for_ : string }
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string
  | Anywhere_start of Pokemon_engine.Pose.place_class
  | Badges_at_least of int
  | Badges of string list
  | Hall_of_fame
  | Caught_at_least of int

let species_list l = String.concat ", " l

let slot_text ({ slot; species } : Postconditions.slot) =
  Printf.sprintf "%s in slot %d" species slot

let includes_text members slots =
  "party includes " ^ species_list (members @ List.map slot_text slots)

let describe = function
  | Party_in_order l -> "party " ^ species_list l
  | Party_includes { members; slots } -> includes_text members slots
  | Member { species; for_ } ->
      Printf.sprintf "%s in the party (%s)" species for_
  | No_mail { species; for_ } ->
      Printf.sprintf "%s holds no Mail (%s)" species for_
  | Holding_no_mail { for_ } ->
      Printf.sprintf "a member holds no Mail (%s)" for_
  | Money_at_least { amount; for_ } ->
      Printf.sprintf "money at least ¥%d (%s)" amount for_
  | Money_between { min; max } -> Printf.sprintf "money ¥%d..¥%d" min max
  | Item_at_least { item; count; for_ } ->
      Printf.sprintf "%s at least x%d (%s)" item count for_
  | Item_exactly { item; count } -> Printf.sprintf "%s x%d" item count
  | Knows_move { move; for_ } ->
      Printf.sprintf "a member knows %s (%s)" move for_
  | Badge { badge; for_ } -> Printf.sprintf "the %s badge (%s)" badge for_
  | Place map -> "at the start, " ^ map
  | Anywhere_start place_class ->
      "at the start, " ^ Pokemon_engine.Pose.place_class_text place_class
  | Badges_at_least n -> Printf.sprintf "at least %d badges" n
  | Badges [ badge ] -> Printf.sprintf "the %s badge" badge
  | Badges names -> "badges " ^ String.concat ", " names
  | Hall_of_fame -> "the Hall of Fame entered"
  | Caught_at_least n -> Printf.sprintf "at least %d species caught" n

let asks_something = function
  | Party_in_order l | Badges l -> l <> []
  | Party_includes { members; slots } -> members <> [] || slots <> []
  | Money_at_least { amount = n; _ }
  | Item_at_least { count = n; _ }
  | Badges_at_least n
  | Caught_at_least n ->
      n > 0
  | Member _ | No_mail _ | Holding_no_mail _ | Knows_move _ | Badge _
  | Money_between _ | Item_exactly _ | Place _ | Anywhere_start _ | Hall_of_fame
    ->
      true
