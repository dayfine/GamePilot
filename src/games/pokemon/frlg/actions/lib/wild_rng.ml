module CR = Pokemon_catch.Catch_runner
module Shiny = Frlg_readers.Shiny_encounter_reader

type policy_catch_steps = {
  find_encounter : unit -> bool;
  detect_shiny : (unit -> Shiny.reading) option;
  on_miss : unit -> unit;
  catch_battle : unit -> CR.outcome;
  finish_catch : Capture.destination -> bool;
}

type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
  policy_catch : policy_catch_steps option;
  shiny_at : int -> bool;
  log : string -> unit;
}

type end_ =
  | Shiny
  | Not_shiny
  | Not_shiny_intro
  | Catch_paused of string
  | Capture_ended of Capture.end_
  | Party_full

type result = { end_ : end_; capture : Capture.result option }

let synthetic_capture (plan : Capture_plan.t) (summary : CR.summary) :
    Capture.result =
  let species =
    match plan.target with Species s -> Some s | Uncaught _ -> None
  in
  {
    end_ = All_caught;
    encounters = 1;
    balls_thrown = summary.balls_thrown;
    caught = [ { species; destination = Party } ];
  }

let confirm_summary game_steps ~party cap =
  let end_ = if game_steps.shiny_at (party + 1) then Shiny else Not_shiny in
  { end_; capture = Some cap }

let check_intro ~log (pc : policy_catch_steps) =
  match pc.detect_shiny with
  | None -> true
  | Some detect ->
      let reading = detect () in
      log ("Wild RNG: " ^ Shiny.format_reading reading);
      if reading.verdict = Shiny.Not_shiny then (
        pc.on_miss ();
        false)
      else true

let finish_policy_catch game_steps (pc : policy_catch_steps) plan ~party summary
    =
  if pc.finish_catch Party then
    confirm_summary game_steps ~party (synthetic_capture plan summary)
  else
    {
      end_ = Capture_ended (Failed "post-catch dialog did not return");
      capture = None;
    }

let run_policy_catch game_steps (pc : policy_catch_steps) plan ~party =
  if not (pc.find_encounter ()) then
    { end_ = Capture_ended No_encounter; capture = None }
  else if not (check_intro ~log:game_steps.log pc) then
    { end_ = Not_shiny_intro; capture = None }
  else
    match pc.catch_battle () with
    | CR.Caught summary -> finish_policy_catch game_steps pc plan ~party summary
    | CR.Paused { reason; _ } -> { end_ = Catch_paused reason; capture = None }
    | CR.No_balls _ ->
        { end_ = Capture_ended (Out_of_balls None); capture = None }
    | CR.Foe_ended _ ->
        { end_ = Capture_ended (Failed "foe ended battle"); capture = None }
    | CR.Failed { reason; _ } ->
        { end_ = Capture_ended (Failed reason); capture = None }

let run_legacy game_steps plan ~party =
  let r = game_steps.catch plan ~party in
  match r.end_ with
  | All_caught -> confirm_summary game_steps ~party r
  | e -> { end_ = Capture_ended e; capture = Some r }

let run game_steps (plan : Capture_plan.t) ~party =
  if party >= Capture.party_size then { end_ = Party_full; capture = None }
  else
    match game_steps.policy_catch with
    | Some pc -> run_policy_catch game_steps pc plan ~party
    | None -> run_legacy game_steps plan ~party

let failure_code = function
  | Shiny -> None
  | Not_shiny -> Some "wild_rng_not_shiny"
  | Not_shiny_intro -> Some "wild_rng_not_shiny_intro"
  | Catch_paused _ -> Some "wild_rng_catch_paused"
  | Capture_ended e -> Some ("wild_rng_" ^ Capture.end_name e)
  | Party_full -> Some "wild_rng_party_full"

let message r =
  match r.end_ with
  | Shiny -> "Wild RNG: the catch is shiny."
  | Not_shiny -> "Wild RNG: the catch is not shiny: the RNG missed its target."
  | Not_shiny_intro -> "Wild RNG: battle intro was not shiny; skipped catch."
  | Catch_paused reason -> "Wild RNG: catch paused for user: " ^ reason ^ "."
  | Capture_ended e -> "Wild RNG: the capture ended " ^ Capture.end_name e ^ "."
  | Party_full ->
      "Wild RNG: the party is full; the catch's summary needs a slot."
