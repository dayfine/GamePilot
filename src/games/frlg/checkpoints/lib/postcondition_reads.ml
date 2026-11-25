module A = Frlg_actions

(* After a read that failed in a menu: B through it back to the overworld, so
   the next read starts there. *)
let back_to_overworld ~log =
  match
    A.Menu_input.run (fun () ->
        A.Menu_input.settle_back ~label:"postcondition read failed" ~log)
  with
  | Ok () -> ()
  | Error cause ->
      log
        ("[Postcondition] not back: "
        ^ Pokemon_engine.Failure.cause_to_string cause)

(* One read in the menu actions' probes; [None] when it failed, but [absent]
   when it failed for want of the item it reads. *)
let read ?absent ~log what body =
  let value = ref None in
  match A.Menu_input.run (fun () -> value := body ()) with
  | Ok () -> !value
  | Error { code = "not_in_bag"; _ } when absent <> None ->
      log (Printf.sprintf "[Postcondition] %s: not in the bag" what);
      back_to_overworld ~log;
      absent
  | Error cause ->
      log
        (Printf.sprintf "[Postcondition] %s not read: %s" what
           (Pokemon_engine.Failure.cause_to_string cause));
      back_to_overworld ~log;
      None

(* The first member read as [species]: its slot, from 1. *)
let slot_of species members =
  let rec find i = function
    | [] -> None
    | Some s :: _ when s = species -> Some i
    | _ :: rest -> find (i + 1) rest
  in
  find 1 members

let member_moves ~log species slot =
  let body () = Some (A.Summary_moves.read_known ~log ~slot) in
  Option.map
    (fun moves -> (species, moves))
    (read ~log ("moves of " ^ species) body)

let member_level ~log species slot =
  Option.map
    (fun level -> (species, level))
    (read ~log ("level of " ^ species) (fun () ->
         A.Member_level.read ~log ~slot))

(* The party as read for the members promised: read when it was not, not when
   no member is promised. *)
let members ~log party ~promised =
  match (promised, party) with
  | false, _ -> None
  | true, Some members -> Some members
  | true, None ->
      read ~log "party" (fun () -> Some (A.Party_species.read_all ~log))

(* Each promised member's [read] on its summary, the member found by its
   species in the party as read. *)
let per_member ~log members species_of read_member promised =
  let one members p =
    let species = species_of p in
    match slot_of species members with
    | None ->
        log ("[Postcondition] " ^ species ^ " not in the party as read");
        None
    | Some slot -> read_member ~log species slot
  in
  match members with
  | None -> []
  | Some members -> List.filter_map (one members) promised

let item_count ~log ({ bag_item; _ } : Pokemon_engine.Postconditions.bag_count)
    =
  Option.map
    (fun count -> (bag_item, count))
    (read ~log ("item " ^ bag_item) (fun () -> A.Bag_items.count ~log bag_item))

let party_marks ~log () =
  Some
    (List.map A.Mail_glitch_use.name_of_mark
       (A.Mail_glitch_use.read_marks ~log))

let observe ~log (promised : Pokemon_engine.Postconditions.t) :
    Pokemon_engine.Postcondition_check.observed =
  let when_promised promised what body =
    if promised then read ~log what body else None
  in
  (* In this order: a record's fields are evaluated in no set order. *)
  let party =
    when_promised (promised.party <> None) "party" (fun () ->
        Some (A.Party_species.read_all ~log))
  in
  let coins =
    when_promised (promised.coins <> None) "coins" (fun () ->
        A.Coin_case.read ~log)
  in
  let caught =
    when_promised (promised.caught <> None) "caught" (fun () ->
        A.Trainer_card_caught.read ~log)
  in
  let money =
    when_promised (promised.money <> None) "money" (fun () ->
        A.Trainer_card_money.read ~log)
  in
  let items = List.filter_map (item_count ~log) promised.items in
  let members =
    members ~log party ~promised:(promised.knows <> [] || promised.levels <> [])
  in
  let knows =
    per_member ~log members
      (fun (k : Pokemon_engine.Postconditions.knows) -> k.species)
      member_moves promised.knows
  in
  let levels =
    per_member ~log members
      (fun (l : Pokemon_engine.Postconditions.level) -> l.species)
      member_level promised.levels
  in
  let marks =
    when_promised (promised.marks <> None) "marks" (party_marks ~log)
  in
  {
    Pokemon_engine.Postcondition_check.nothing_read with
    party;
    items;
    coins;
    caught;
    money;
    knows;
    levels;
    marks;
  }

let gained : Engine_postcondition.Count.t -> bool = function
  | Engine_postcondition.Count.Gained _ -> true
  | Engine_postcondition.Count.Exactly _ | Engine_postcondition.Count.At_least _
    ->
      false

let at_start ~log (promised : Pokemon_engine.Postconditions.t) =
  let spent =
    match promised.money with
    | Some (Engine_postcondition.Money.Spent _) -> true
    | _ -> false
  and coins = Option.fold ~none:false ~some:gained promised.coins
  and caught = Option.fold ~none:false ~some:gained promised.caught
  and items =
    List.filter
      (fun (b : Pokemon_engine.Postconditions.bag_count) -> gained b.count)
      promised.items
  in
  if spent || coins || caught || items <> [] then
    log "[Postcondition] at the start, for what the checkpoint changes:";
  let start_money =
    if spent then
      read ~log "money at the start" (fun () -> A.Trainer_card_money.read ~log)
    else None
  in
  let start_coins =
    (* No Coin Case yet (mg-01 gets it): no coins. *)
    if coins then
      read ~absent:0 ~log "coins at the start" (fun () -> A.Coin_case.read ~log)
    else None
  in
  let start_caught =
    if caught then
      read ~log "caught at the start" (fun () ->
          A.Trainer_card_caught.read ~log)
    else None
  in
  let start_items = List.filter_map (item_count ~log) items in
  {
    Pokemon_engine.Postcondition_check.start_money;
    start_coins;
    start_caught;
    start_items;
  }

let party_summary ~log =
  read ~log "party summary" (fun () -> Some (A.Party_summary.read_all ~log ()))

let trainer_card ~log =
  read ~log "Trainer Card badges" (fun () -> A.Trainer_card_badges.read ~log)
