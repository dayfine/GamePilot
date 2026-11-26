module C = Plza_gift_catalog.Gift_catalog
module Failure = Engine_run.Failure

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
  arrange_slots : C.box_slot list -> (Gift_boxes.arranged, string) result;
  save : unit -> (unit, string) result;
  log : string -> unit;
}

type run = {
  catalog : C.t;
  today : C.date;
  mutable outcomes : (C.gift * outcome) list;
  mutable moved : int;
}

let start catalog ~today =
  {
    catalog;
    today;
    outcomes = List.map (fun g -> (g, Not_tried)) catalog;
    moved = 0;
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
      "Party of six: every gift lands in a box; slot 6 is taken for a gift an \
       earlier run left there."
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

(* A Pokémon gift that may be in the save: received now, said to be by the
   game, or failed (an earlier run's gift shows an unknown screen today). *)
let may_have = function
  | Claimed | Already_received | Failed _ -> true
  | Expired | Not_supported _ | Not_tried -> false

(* Those gifts, the ones received now first, each in the catalog's order:
   the order the game put them in party slot 6 and the boxes. *)
let boxed_gifts run =
  let pokemon =
    List.filter_map
      (fun ((g : C.gift), o) ->
        match g.pokemon with
        | Some p when may_have o -> Some ((g, o), p)
        | _ -> None)
      run.outcomes
  in
  let now, before = List.partition (fun ((_, o), _) -> o = Claimed) pokemon in
  now @ before

let slot_name (s : C.box_slot) = Printf.sprintf "Box %d slot %d" s.box s.slot

(* A gift received now or said to be must read in its slot; a failed one
   keeps its failure. *)
let judge run (((gift : C.gift), outcome), (p : C.pokemon)) reads =
  let fail why = set run gift (Failed (slot_name p.box_slot ^ why)) in
  match (outcome, List.assoc_opt p.box_slot reads) with
  | (Failed _ | Expired | Not_supported _ | Not_tried), _
  | _, Some Gift_boxes.Filled ->
      ()
  | _, Some Empty -> fail " is empty"
  | _, Some (Not_read why) -> fail (" not read: " ^ why)
  | _, None -> fail " not read"

let arrange steps run gifts =
  let slots = List.map (fun (_, (p : C.pokemon)) -> p.box_slot) gifts in
  match steps.arrange_slots slots with
  | Ok { reads; moved } ->
      run.moved <- moved;
      List.iter (fun g -> judge run g reads) gifts;
      Ok ()
  | Error why -> fail "boxes_not_read" why

let check_gift_slots steps run =
  match boxed_gifts run with
  | [] ->
      steps.log "No Pokémon gift in the save: no box slot to arrange.";
      Ok ()
  | gifts -> arrange steps run gifts

let save_progress steps run =
  if List.exists (fun (_, o) -> o = Claimed) run.outcomes || run.moved > 0 then
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
