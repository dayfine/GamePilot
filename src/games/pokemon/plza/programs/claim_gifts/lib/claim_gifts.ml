module C = Plza_gift_catalog.Gift_catalog
module Failure = Engine_run.Failure

let ( let* ) = Result.bind

type party = Full | Room_for_one
type party_read = Party of party | No_menu of string | Not_ready of string

type outcome =
  | Claimed
  | Already_received
  | Expired
  | Not_supported of string
  | Failed of string
  | Not_tried

type game_steps = {
  read_party : unit -> party_read;
  claim : C.gift -> Gift_claim.claim;
  settle_boxes : C.box_slot list -> (Gift_boxes.settled, string) result;
  save : unit -> (unit, string) result;
  log : string -> unit;
}

type run = {
  catalog : C.t;
  today : C.date;
  mutable outcomes : (C.gift * outcome) list;
  mutable moved : bool;
  mutable before : (C.box_slot * Gift_boxes.slot_read) list;
}

let start catalog ~today =
  {
    catalog;
    today;
    outcomes = List.map (fun g -> (g, Not_tried)) catalog;
    moved = false;
    before = [];
  }

let outcomes run = run.outcomes

let set run (gift : C.gift) outcome =
  run.outcomes <-
    List.map
      (fun ((g : C.gift), o) -> if g.id = gift.id then (g, outcome) else (g, o))
      run.outcomes

let outcome_text = function
  | Claimed -> "claimed"
  | Already_received -> "already received"
  | Expired -> "expired, skipped"
  | Not_supported why -> "not supported: " ^ why
  | Failed why -> "failed: " ^ why
  | Not_tried -> "not tried"

let fail code detail = Error (Failure.cause ~repeats:true code detail)

let party_text = function
  | Full ->
      "Party of six: slot 6 is taken for a gift an earlier run left there, \
       moved to Box 1 before the claims."
  | Room_for_one -> "Party of five: the first gift lands in party slot 6."

let gifts_start steps run =
  steps.log ("Today (UTC): " ^ C.date_to_string run.today);
  List.iter (fun l -> steps.log ("Gift " ^ l)) (C.lines run.catalog);
  match steps.read_party () with
  | Party p ->
      steps.log (party_text p);
      Ok ()
  | No_menu why -> fail "not_on_main_menu" why
  | Not_ready why ->
      fail "party_not_ready"
        ("five or six Pokémon at full HP are needed (heal the party): " ^ why)

(* What came of a claim, and whether the run can go on to the next gift. *)
let of_claim : Gift_claim.claim -> outcome * bool = function
  | Received -> (Claimed, true)
  | Already_received -> (Already_received, true)
  | Not_received why -> (Failed why, true)
  | Lost why -> (Failed why, false)

let try_gift steps run (gift : C.gift) =
  if C.expired ~today:run.today gift then (
    steps.log (C.skipped_line gift);
    (Expired, true))
  else
    match gift.how with
    | Home -> (Not_supported "HOME gifts are received in Pokémon HOME", true)
    | Code | Internet -> of_claim (steps.claim gift)

let claim_one steps run gift =
  let outcome, go_on = try_gift steps run gift in
  set run gift outcome;
  go_on

let claim_gifts steps run =
  let rec go = function
    | [] -> Ok ()
    | gift :: rest ->
        if claim_one steps run gift then go rest
        else fail "screen_lost" ("the main menu was lost after " ^ gift.id)
  in
  go run.catalog

let slot_name (s : C.box_slot) = Printf.sprintf "Box %d slot %d" s.box s.slot

let read_text = function
  | Gift_boxes.Filled -> "holds a Pokémon"
  | Empty -> "is empty"
  | Not_read why -> "not read: " ^ why

(* Settled, each slot's reading logged; whether party slot 6 moved. *)
let settle steps run slots =
  match steps.settle_boxes slots with
  | Ok { reads; moved } ->
      List.iter
        (fun (s, r) -> steps.log (slot_name s ^ " " ^ read_text r ^ "."))
        reads;
      run.moved <- run.moved || moved;
      Ok reads
  | Error why -> fail "boxes_not_read" why

(* The Pokémon gifts with an [outcome] that [keep] keeps, in the catalog's
   order: the order they are received in. *)
let pokemon_gifts run keep =
  List.filter_map
    (fun ((g : C.gift), o) ->
      match g.pokemon with Some p when keep o -> Some (g, p) | _ -> None)
    run.outcomes

let slots gifts = List.map (fun (_, (p : C.pokemon)) -> p.box_slot) gifts

(* Before the claims: the Pokémon gifts not expired nor received in HOME. *)
let settle_boxes steps run =
  let due ((g : C.gift), _) =
    g.how <> Home && not (C.expired ~today:run.today g)
  in
  match List.filter due (pokemon_gifts run (fun _ -> true)) with
  | [] ->
      steps.log "No Pokémon gift due: the Boxes not opened.";
      Ok ()
  | gifts ->
      let* reads = settle steps run (slots gifts) in
      run.before <- reads;
      Ok ()

(* A gift received now, its slot read after the claims; a slot that held a
   Pokémon before them holds something else. *)
let not_in_place run reads ((g : C.gift), (p : C.pokemon)) =
  let held_before = List.assoc_opt p.box_slot run.before = Some Filled in
  match List.assoc_opt p.box_slot reads with
  | _ when held_before ->
      Some (g, slot_name p.box_slot ^ " held a Pokémon before the claims")
  | Some Gift_boxes.Filled -> None
  | Some r -> Some (g, slot_name p.box_slot ^ " " ^ read_text r)
  | None -> Some (g, slot_name p.box_slot ^ " not read")

let missing_text missing =
  String.concat "; "
    (List.map (fun ((g : C.gift), why) -> g.id ^ ": " ^ why) missing)

(* The gifts read out of place failed, the run stopped. *)
let check_in_place run reads gifts =
  match List.filter_map (not_in_place run reads) gifts with
  | [] -> Ok ()
  | missing ->
      List.iter (fun (g, why) -> set run g (Failed why)) missing;
      fail "gifts_not_in_place" (missing_text missing)

(* After the claims: each Pokémon gift received now in its slot. *)
let check_gift_slots steps run =
  match pokemon_gifts run (fun o -> o = Claimed) with
  | [] ->
      steps.log "No Pokémon received: no box slot to check.";
      Ok ()
  | gifts ->
      let* reads = settle steps run (slots gifts) in
      check_in_place run reads gifts

let save_progress steps run =
  if List.exists (fun (_, o) -> o = Claimed) run.outcomes || run.moved then
    Result.map_error (Failure.cause ~repeats:true "not_saved") (steps.save ())
  else (
    steps.log "Nothing received or moved: not saved.";
    Ok ())

let failed run =
  List.filter_map
    (fun ((g : C.gift), o) ->
      match o with Failed why -> Some (g.id ^ " (" ^ why ^ ")") | _ -> None)
    run.outcomes

let report_gifts steps run =
  List.iter
    (fun (g, o) -> steps.log (C.line g ^ ": " ^ outcome_text o))
    run.outcomes;
  match failed run with
  | [] -> Ok ()
  | ids -> fail "gifts_failed" (String.concat "; " ids)

let no_args action steps run (event : Plza_engine.Plan.event) = function
  | [] -> action steps run
  | (key, _) :: _ ->
      fail "bad_args" (event.id ^ ": " ^ key ^ " is not an arg of this action")

let actions =
  [
    ("gifts_start", gifts_start);
    ("settle_boxes", settle_boxes);
    ("claim_gifts", claim_gifts);
    ("check_gift_slots", check_gift_slots);
    ("save_progress", save_progress);
    ("report_gifts", report_gifts);
  ]

let game_actions steps run =
  List.map (fun (name, action) -> (name, no_args action steps run)) actions

let check_event (e : Plza_engine.Plan.event) =
  match (e.kind, e.way) with
  | Named_action _, Some name when List.mem_assoc name actions -> Ok ()
  | _ ->
      Error
        (Printf.sprintf "event %s: only game actions of %s" e.id
           (String.concat ", " (List.map fst actions)))

let check_plan (plan : Plza_engine.Plan.t) =
  if plan.execution <> [] then Error "the plan's execution must be {}"
  else
    List.fold_left
      (fun acc e -> Result.bind acc (fun () -> check_event e))
      (Ok ()) plan.checkpoint.events
