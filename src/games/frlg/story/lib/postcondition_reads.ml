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
      log ("[Postcondition] not back: " ^ Story.Failure.cause_to_string cause)

(* One read in the menu actions' probes; [None] when it failed. *)
let read ~log what body =
  let value = ref None in
  match A.Menu_input.run (fun () -> value := body ()) with
  | Ok () -> !value
  | Error cause ->
      log
        (Printf.sprintf "[Postcondition] %s not read: %s" what
           (Story.Failure.cause_to_string cause));
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

(* Each promised member's moves, on its summary; the party read first when it
   was not. *)
let knows ~log party (promised : Story.Plan.knows list) =
  let members =
    match (promised, party) with
    | [], _ -> None
    | _, Some members -> Some members
    | _, None ->
        read ~log "party" (fun () -> Some (A.Party_species.read_all ~log))
  in
  let moves members ({ species; _ } : Story.Plan.knows) =
    match slot_of species members with
    | None ->
        log ("[Postcondition] " ^ species ^ " not in the party as read");
        None
    | Some slot -> member_moves ~log species slot
  in
  match members with
  | None -> []
  | Some members -> List.filter_map (moves members) promised

let observe ~log (promised : Story.Plan.postconditions) :
    Story.Postcondition_check.observed =
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
  let money =
    when_promised (promised.money <> None) "money" (fun () ->
        A.Trainer_card_money.read ~log)
  in
  let items =
    List.filter_map
      (fun ({ item; _ } : Story.Plan.item) ->
        Option.map
          (fun count -> (item, count))
          (read ~log ("item " ^ item) (fun () -> A.Bag_items.count ~log item)))
      promised.items
  in
  let knows = knows ~log party promised.knows in
  {
    Story.Postcondition_check.nothing_read with
    party;
    items;
    coins;
    money;
    knows;
  }
