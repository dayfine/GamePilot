module Postconditions = Pokemon_engine.Postconditions
open Need

type read = {
  observed : Pokemon_engine.Postcondition_check.observed;
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

(* The first member of the species (the one the deposit stores) and its mark. *)
let slot_mark species (read : read) =
  match (read.observed.party, read.observed.marks) with
  | Some party, Some marks ->
      Option.bind
        (List.find_index (( = ) (Some species)) party)
        (fun i -> Option.map (fun mark -> (i + 1, mark)) (List.nth_opt marks i))
  | _ -> None

let no_mail_row read ~need species =
  let mail = Frlg_actions.Mail_glitch_use.name_of_mark Mail in
  match slot_mark species read with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some (slot, mark) ->
      {
        need;
        read = Printf.sprintf "%s in slot %d: %s" species slot mark;
        verdict = of_bool (mark <> mail);
      }

let first_without_mail marks =
  let mail = Frlg_actions.Mail_glitch_use.name_of_mark Mail in
  List.find_index (fun m -> m <> mail) marks

let holding_no_mail_row (read : read) ~need =
  match Option.map first_without_mail read.observed.marks with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some None -> { need; read = "every member holds Mail"; verdict = Mismatch }
  | Some (Some i) ->
      let read = Printf.sprintf "slot %d holds no Mail" (i + 1) in
      { need; read; verdict = Ok }

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

let row read need =
  let text = Need.describe need in
  match need with
  | Party_in_order l ->
      with_party read text (fun m -> m = List.map Option.some l)
  | Party_includes { members; slots } ->
      with_party read text (fun m ->
          List.for_all (has m) members && List.for_all (in_slot m) slots)
  | Member { species; _ } -> with_party read text (fun m -> has m species)
  | No_mail { species; _ } -> no_mail_row read ~need:text species
  | Holding_no_mail _ -> holding_no_mail_row read ~need:text
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
  | Anywhere_start _ ->
      (* The run's first event, a Fly, checks it at no cost: the game refuses
         to fly indoors before anything changes. *)
      { need = text; read = "not read: the first Fly checks it"; verdict = Ok }
  | Badges_at_least n -> badge_count_row read ~need:text n
  | Badges names -> badges_row read ~need:text names
  | Hall_of_fame -> hall_of_fame_row read ~need:text
  | Caught_at_least n -> caught_row read ~need:text n
