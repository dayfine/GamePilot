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
  { Story.Postcondition_check.nothing_read with party; coins; money }
