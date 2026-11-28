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
  show_counters : Wire.Watch.counter list -> unit;
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

let watch_counters ~attempt ~total ~phase : Wire.Watch.counter list =
  [
    { label = "attempt"; value = Printf.sprintf "%d/%d" attempt total };
    { label = "phase"; value = phase };
  ]

let report game_steps ~attempt ~total phase =
  game_steps.show_counters (watch_counters ~attempt ~total ~phase)

let confirm_summary game_steps ~attempt ~total ~party cap =
  report game_steps ~attempt ~total "summary";
  if game_steps.shiny_at (party + 1) then (
    report game_steps ~attempt ~total "shiny";
    { end_ = Shiny; capture = Some cap })
  else { end_ = Not_shiny; capture = Some cap }

let check_intro ~label game_steps ~attempt ~total (pc : policy_catch_steps) =
  match pc.detect_shiny with
  | None -> true
  | Some detect ->
      report game_steps ~attempt ~total "encounter";
      let reading = detect () in
      game_steps.log (label ^ ": " ^ Shiny.format_reading reading);
      if reading.verdict = Shiny.Not_shiny then (
        pc.on_miss ();
        false)
      else true

let finish_policy_catch game_steps (pc : policy_catch_steps) plan ~attempt
    ~total ~party summary =
  if pc.finish_catch Party then
    confirm_summary game_steps ~attempt ~total ~party
      (synthetic_capture plan summary)
  else
    {
      end_ = Capture_ended (Failed "post-catch dialog did not return");
      capture = None;
    }

let run_policy_catch ~label game_steps (pc : policy_catch_steps)
    (plan : Capture_plan.t) ~party =
  let total = plan.max_encounters in
  report game_steps ~attempt:1 ~total "reset";
  if not (pc.find_encounter ()) then
    { end_ = Capture_ended No_encounter; capture = None }
  else if not (check_intro ~label game_steps ~attempt:1 ~total pc) then
    { end_ = Not_shiny_intro; capture = None }
  else (
    report game_steps ~attempt:1 ~total "catch";
    match pc.catch_battle () with
    | CR.Caught summary ->
        finish_policy_catch game_steps pc plan ~attempt:1 ~total ~party summary
    | CR.Paused { reason; _ } -> { end_ = Catch_paused reason; capture = None }
    | CR.No_balls _ ->
        { end_ = Capture_ended (Out_of_balls None); capture = None }
    | CR.Foe_ended _ ->
        { end_ = Capture_ended (Failed "foe ended battle"); capture = None }
    | CR.Failed { reason; _ } ->
        { end_ = Capture_ended (Failed reason); capture = None })

let run_legacy game_steps (plan : Capture_plan.t) ~party =
  let total = plan.max_encounters in
  report game_steps ~attempt:1 ~total "reset";
  let r = game_steps.catch plan ~party in
  match r.end_ with
  | All_caught ->
      confirm_summary game_steps ~attempt:(max 1 r.encounters) ~total ~party r
  | e -> { end_ = Capture_ended e; capture = Some r }

let run ?(label = "Wild RNG") game_steps (plan : Capture_plan.t) ~party =
  if party >= Capture.party_size then { end_ = Party_full; capture = None }
  else
    match game_steps.policy_catch with
    | Some pc -> run_policy_catch ~label game_steps pc plan ~party
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
