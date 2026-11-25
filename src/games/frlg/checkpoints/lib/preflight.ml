module P = Pokemon_engine.Plan
module Postconditions = Pokemon_engine.Postconditions

type need = Need.t =
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

(* The declared preconditions first: the save's state the plan's goal implies,
   before what its events' args need. *)
let needs stocks ~before plan =
  Result.map
    (fun declared -> declared @ Plan_needs.needs stocks ~before plan)
    (Plan_preconditions.needs plan)

type read = Need_check.read = {
  observed : Pokemon_engine.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
  members : Room_policy.member list option;
  card : Frlg_readers.Trainer_card_front.t option;
}

type verdict = Need_check.verdict = Ok | Mismatch | Not_read
type row = Need_check.row = { need : string; read : string; verdict : verdict }

let describe = Need.describe
let asks_something = Need.asks_something
let compare needs read = List.map (Need_check.row read) needs

let room need read =
  let need_text, read_text, ok =
    Party_room.report need ~members:read.members read.observed.party
  in
  let verdict =
    match ok with Some true -> Ok | Some false -> Mismatch | None -> Not_read
  in
  { need = need_text; read = read_text; verdict }

let passed rows = List.for_all (fun r -> r.verdict = Ok) rows

let verdict_text = function
  | Ok -> "ok"
  | Mismatch -> "MISMATCH"
  | Not_read -> "NOT READ"

let table rows =
  let width f =
    List.fold_left (fun w r -> max w (String.length (f r))) 4 rows
  in
  let wn = width (fun r -> r.need) and wr = width (fun r -> r.read) in
  let line a b c = Printf.sprintf "%-*s  %-*s  %s" wn a wr b c in
  String.concat "\n"
    (line "NEED" "READ" "VERDICT"
    :: List.map (fun r -> line r.need r.read (verdict_text r.verdict)) rows)

let reads_card = Need_reads.reads_card
let to_read = Need_reads.to_read
