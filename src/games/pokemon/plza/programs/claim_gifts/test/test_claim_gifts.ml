(* Claim_gifts' decisions, run through the engine's runner over the
   program's own plan (plans/01-claim-gifts.plan.json) and its catalog
   (gifts.json: Vivillon by Internet to Box 1 slot 2, Xerneas by code to slot
   1, PREPAR1NG's items by code). The game is fake_game_steps: a party read, a
   claim result per gift id, a slot read per slot, a count of Pokémon moved
   and a save that are given by each case, every call recorded; nothing
   presses a button. Today is a fixed day, never the clock. *)

module C = Plza_gift_catalog.Gift_catalog
module Cg = Plza_claim_gifts.Claim_gifts
module Gc = Plza_claim_gifts.Gift_claim
module Gb = Plza_claim_gifts.Gift_boxes

let catalog =
  Result.get_ok
    (Plza_gift_catalog.Gift_catalog_decode.of_json
       (Yojson.Safe.from_file "../../../gift_catalog/gifts.json"))

let plan =
  Result.get_ok
    (Plza_engine.Plan_decode.load "../plans/01-claim-gifts.plan.json")

let day s = Result.get_ok (C.date_of_string s)

type fake = {
  party : Cg.party_read;
  claims : (string * Gc.claim) list;  (** by gift id; Received when absent *)
  slots : (int * Gb.slot_read) list;  (** by Box 1 slot; Filled when absent *)
  moved : int;
  today : string;
}

let base =
  {
    party = Party Full;
    claims = [];
    slots = [];
    moved = 0;
    today = "2026-11-25";
  }

type result = {
  ran : (unit, string) Stdlib.result;
  calls : string list;
  outcomes : (string * string) list;
}

let slot_text (s : C.box_slot) = string_of_int s.slot

let fake_game_steps f calls : Cg.game_steps =
  let call s = calls := !calls @ [ s ] in
  {
    read_party =
      (fun () ->
        call "read_party";
        f.party);
    claim =
      (fun g ->
        call ("claim " ^ g.id);
        Option.value ~default:Gc.Received (List.assoc_opt g.id f.claims));
    arrange_slots =
      (fun slots ->
        call
          (Printf.sprintf "arrange %s"
             (String.concat "," (List.map slot_text slots)));
        let read (s : C.box_slot) =
          (s, Option.value ~default:Gb.Filled (List.assoc_opt s.slot f.slots))
        in
        Ok { reads = List.map read slots; moved = f.moved });
    save =
      (fun () ->
        call "save";
        Ok ());
    log = ignore;
  }

let no_handler _ = Error (Engine_run.Failure.cause "no_handler" "")

let run f =
  let calls = ref [] in
  let r = Cg.start catalog ~today:(day f.today) in
  let game : Plza_engine.Game.t =
    {
      run_own = (fun _ _ -> no_handler ());
      run_builtin = no_handler;
      game_actions = Cg.game_actions (fake_game_steps f calls) r;
      flag_holds = (fun _ -> false);
      position = (fun () -> None);
      between_rounds = (fun () -> Ok ());
      save = (fun () -> Ok ());
      reload = (fun () -> Ok ());
      log = ignore;
    }
  in
  let ran =
    Result.map_error
      (fun (e : Plza_engine.Failure.t) ->
        match e.reason with Handler c -> c.code | _ -> "other")
      (Plza_engine.Runner.run game plan.checkpoint)
  in
  {
    ran;
    calls = !calls;
    outcomes =
      List.map
        (fun ((g : C.gift), o) -> (g.id, Cg.outcome_text o))
        (Cg.outcomes r);
  }

let ran f () = match (run f).ran with Ok () -> "ok" | Error code -> code
let called f what () = string_of_bool (List.mem what (run f).calls)

let outcome f id () =
  Option.value ~default:"absent" (List.assoc_opt id (run f).outcomes)

let case name input expectation : Table_test.case = { name; input; expectation }
let viv = "vivillon-poke-ball"
let xer = "xerneas-30th"
let items = "prepar1ng-items"

let all_received =
  [
    case "every gift received: the run passes" (ran base) "ok";
    case "every gift received: Vivillon claimed" (outcome base viv) "claimed";
    case "every gift received: the items claimed" (outcome base items) "claimed";
    case "both Pokémon arranged, in the catalog's order"
      (called base "arrange 2,1")
      "true";
    case "something received: saved" (called base "save") "true";
  ]

let room = { base with party = Party Room_for_one }

let party_cases =
  [
    case "a party of five: both Pokémon arranged as from a party of six"
      (called room "arrange 2,1")
      "true";
    case "a party not ready: the run stops"
      (ran { base with party = Not_ready "0.20" })
      "party_not_ready";
    case "a party not ready: nothing claimed"
      (called { base with party = Not_ready "0.20" } ("claim " ^ viv))
      "false";
    case "no main menu: the run stops"
      (ran { base with party = No_menu "none" })
      "not_on_main_menu";
  ]

let later = { base with today = "2027-01-08" }

let expiry_cases =
  [
    case "past Xerneas' last day: it is skipped" (outcome later xer)
      "expired, skipped";
    case "past Xerneas' last day: it is not claimed"
      (called later ("claim " ^ xer))
      "false";
    case "on Xerneas' last day: it is claimed"
      (called { base with today = "2027-01-07" } ("claim " ^ xer))
      "true";
    case "past Xerneas' last day: the run passes" (ran later) "ok";
  ]

let missed = { base with claims = [ (viv, Gc.Not_received "unknown screen") ] }
let lost = { base with claims = [ (viv, Gc.Lost "no main menu") ] }

let failure_cases =
  [
    case "a gift not received fails" (outcome missed viv)
      "failed: unknown screen";
    case "a gift not received: the next is still claimed"
      (called missed ("claim " ^ xer))
      "true";
    case "a gift not received: the others are saved" (called missed "save")
      "true";
    case "a gift not received: the run fails at the report" (ran missed)
      "gifts_failed";
    case "the menu lost: the run stops" (ran lost) "screen_lost";
    case "the menu lost: the next gift is not tried" (outcome lost xer)
      "not tried";
    case "the menu lost: nothing saved" (called lost "save") "false";
    case "already received counts as done"
      (ran { base with claims = [ (xer, Gc.Already_received) ] })
      "ok";
  ]

let none_received =
  {
    base with
    claims =
      List.map (fun (g : C.gift) -> (g.id, Gc.Not_received "no list")) catalog;
  }

let empty_slot = { base with slots = [ (1, Gb.Empty) ] }

let slot_cases =
  [
    case "an empty box slot fails its gift" (outcome empty_slot xer)
      "failed: Box 1 slot 1 is empty";
    case "an empty box slot leaves the other gift claimed"
      (outcome empty_slot viv) "claimed";
    case "nothing received: not saved" (called none_received "save") "false";
    case "nothing received: both slots still arranged, as an earlier run's"
      (called none_received "arrange 2,1")
      "true";
  ]

(* A rerun: every gift already in the save, Vivillon failing as an unknown
   screen (no reader for "already received" yet), the others said to be
   received. *)
let rerun =
  {
    base with
    claims =
      [
        (viv, Gc.Not_received "unknown screen");
        (xer, Gc.Already_received);
        (items, Gc.Already_received);
      ];
  }

let moved_rerun = { rerun with moved = 2 }
let received_now = { base with claims = [ (viv, Gc.Already_received) ] }
let all_expired = { base with today = "2027-04-01" }

let rerun_cases =
  [
    case "a rerun: both Pokémon arranged" (called rerun "arrange 2,1") "true";
    case "a gift received now goes first: party slot 6 holds it"
      (called received_now "arrange 1,2")
      "true";
    case "a rerun that moved Pokémon: saved" (called moved_rerun "save") "true";
    case "a rerun with everything in place: not saved" (called rerun "save")
      "false";
    case "a rerun: Xerneas in its slot is done" (outcome rerun xer)
      "already received";
    case "a rerun: Vivillon keeps its failure" (outcome rerun viv)
      "failed: unknown screen";
    case "already received, its slot empty: it fails"
      (outcome { rerun with slots = [ (1, Gb.Empty) ] } xer)
      "failed: Box 1 slot 1 is empty";
    case "every gift expired: nothing arranged"
      (called all_expired "arrange 2,1")
      "false";
  ]

let () =
  Table_test.run "claim_gifts"
    (all_received @ party_cases @ expiry_cases @ failure_cases @ slot_cases
   @ rerun_cases)
