module P = Pokemon_checkpoints.Plan
module Postconditions = Pokemon_checkpoints.Postconditions

type need = Plan_needs.need =
  | Party_in_order of string list
  | Party_includes of {
      members : string list;
      slots : Postconditions.slot list;
    }
  | Member of { species : string; for_ : string }
  | Knows_move of { move : string; for_ : string }
  | Badge of { badge : string; for_ : string }
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string
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

type read = {
  observed : Pokemon_checkpoints.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
  members : Room_policy.member list option;
  card : Frlg_readers.Trainer_card_front.t option;
}

type verdict = Ok | Mismatch | Not_read
type row = { need : string; read : string; verdict : verdict }

let of_bool b = if b then Ok else Mismatch
let species_list l = String.concat ", " l

let party_text = function
  | None -> "not read"
  | Some members -> species_list (List.map (Option.value ~default:"?") members)

let with_party (read : read) need test =
  match read.observed.party with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some members ->
      {
        need;
        read = party_text (Some members);
        verdict = of_bool (test members);
      }

let has members species = List.mem (Some species) members

let in_slot members ({ slot; species } : Postconditions.slot) =
  List.nth_opt members (slot - 1) = Some (Some species)

let slot_text ({ slot; species } : Postconditions.slot) =
  Printf.sprintf "%s in slot %d" species slot

let includes_text members slots =
  "party includes " ^ species_list (members @ List.map slot_text slots)

(* Its moves as read; a member not in the party read is a mismatch. *)
let knows (move : string) (m : Room_policy.member) =
  Option.fold ~none:false ~some:(List.mem move) m.moves

let unread_moves (m : Room_policy.member) = m.moves = None

let knows_row (read : read) ~need move =
  match read.members with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some members -> (
      match List.find_opt (knows move) members with
      | Some m -> { need; read = m.species ^ " knows " ^ move; verdict = Ok }
      | None when List.exists unread_moves members ->
          { need; read = "moves not read"; verdict = Not_read }
      | None -> { need; read = "no member knows " ^ move; verdict = Mismatch })

let with_money (read : read) need test =
  match read.observed.money with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some m ->
      { need; read = Printf.sprintf "¥%d" m; verdict = of_bool (test m) }

let with_item (read : read) item need test =
  match List.assoc_opt item read.observed.items with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some n ->
      {
        need;
        read = Printf.sprintf "%s x%d" item n;
        verdict = of_bool (test n);
      }

let place_row read ~need =
  match read.place with
  | None ->
      { need; read = "no kept start frame to compare"; verdict = Not_read }
  | Some d ->
      let module F = Frlg_readers.Start_frame in
      {
        need;
        read = F.difference_to_string d;
        verdict = of_bool (F.same_place d);
      }

module Card = Frlg_readers.Trainer_card_front

let with_card (read : read) need judge =
  match read.card with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some card ->
      let ok, text = judge card in
      { need; read = text; verdict = of_bool ok }

let badge_count_row read ~need n =
  with_card read need (fun card ->
      let have = List.length (Card.earned card) in
      ( have >= n,
        if have >= n then Card.to_string card
        else Printf.sprintf "%s; %d short" (Card.to_string card) (n - have) ))

let missing_badges names card =
  let earned = Card.earned card in
  List.filter (fun b -> not (List.mem b earned)) names

let badges_text card = function
  | [] -> Card.to_string card
  | missing -> Card.to_string card ^ "; missing " ^ String.concat ", " missing

let badges_row read ~need names =
  with_card read need (fun card ->
      let missing = missing_badges names card in
      (missing = [], badges_text card missing))

let hall_of_fame_row read ~need =
  with_card read need (fun card ->
      ( Card.hall_of_fame card,
        if Card.hall_of_fame card then Card.to_string card ^ ": entered"
        else "no star: the Hall of Fame not entered" ))

let caught_text ~need have =
  if have >= need then Printf.sprintf "%d caught" have
  else Printf.sprintf "%d caught; %d short" have (need - have)

let caught_row (read : read) ~need n =
  match read.observed.caught with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some have ->
      { need; read = caught_text ~need:n have; verdict = of_bool (have >= n) }

let describe = function
  | Party_in_order l -> "party " ^ species_list l
  | Party_includes { members; slots } -> includes_text members slots
  | Member { species; for_ } ->
      Printf.sprintf "%s in the party (%s)" species for_
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
  | Member _ | Knows_move _ | Badge _ | Money_between _ | Item_exactly _
  | Place _ | Hall_of_fame ->
      true

let row read need =
  let text = describe need in
  match need with
  | Party_in_order l ->
      with_party read text (fun m -> m = List.map Option.some l)
  | Party_includes { members; slots } ->
      with_party read text (fun m ->
          List.for_all (has m) members && List.for_all (in_slot m) slots)
  | Member { species; _ } -> with_party read text (fun m -> has m species)
  | Money_at_least { amount; _ } -> with_money read text (fun m -> m >= amount)
  | Money_between { min; max } ->
      with_money read text (fun m -> m >= min && m <= max)
  | Item_at_least { item; count; _ } ->
      with_item read item text (fun n -> n >= count)
  | Item_exactly { item; count } ->
      with_item read item text (fun n -> n = count)
  | Knows_move { move; _ } -> knows_row read ~need:text move
  | Badge { badge; _ } -> badges_row read ~need:text [ badge ]
  | Place _ -> place_row read ~need:text
  | Badges_at_least n -> badge_count_row read ~need:text n
  | Badges names -> badges_row read ~need:text names
  | Hall_of_fame -> hall_of_fame_row read ~need:text
  | Caught_at_least n -> caught_row read ~need:text n

let compare needs read = List.map (row read) needs

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

let reads_card =
  List.exists (function
    | Badges_at_least _ | Badges _ | Badge _ | Hall_of_fame -> true
    | _ -> false)

(* An item or the money named only so that it is read (to_read). *)
let any_count bag_item =
  { Postconditions.bag_item; count = Engine_postcondition.Count.Exactly 0 }

let any_money = Engine_postcondition.Money.Range { min = 0; max = 0 }

let to_read needs : Postconditions.t =
  let party =
    List.exists
      (function
        | Party_in_order _ | Party_includes _ | Member _ | Knows_move _ -> true
        | _ -> false)
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
    marks = None;
  }
