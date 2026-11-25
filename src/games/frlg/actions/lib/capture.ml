type destination = Party | Pc
type throw_end = Caught | Broke_free | No_balls | Throw_failed
type encounter = { species : string option; caught : bool }

type game_steps = {
  find_encounter : unit -> bool;
  read_encounter : unit -> encounter;
  flee : unit -> bool;
  throw_ball : unit -> throw_end;
  finish_catch : destination -> bool;
  log : string -> unit;
}

type end_ =
  | All_caught
  | Out_of_encounters
  | Out_of_balls of string option
  | No_encounter
  | Failed of string

type catch = { species : string option; destination : destination }

type result = {
  end_ : end_;
  encounters : int;
  balls_thrown : int;
  caught : catch list;
}

let max_turns = 20
let party_size = 6

(* One capture under way: what it has counted, and its party. *)
type under_way = {
  game_steps : game_steps;
  plan : Capture_plan.t;
  mutable party : int;
  mutable encounters : int;
  mutable balls : int;
  mutable caught : catch list;
}

exception Ended of end_

let stop end_ = raise (Ended end_)
let target r = Capture_plan.target_name r.plan.target
let species_name s = Option.value s ~default:"an unread species"

let run_and_stop r end_ =
  if r.game_steps.flee () then stop end_
  else stop (Failed ("couldn't run from " ^ target r))

let destination_name = function Party -> "party" | Pc -> "PC"

let next_encounter r =
  if r.encounters >= r.plan.max_encounters then stop Out_of_encounters;
  if r.balls >= r.plan.max_balls then stop (Out_of_balls None);
  if not (r.game_steps.find_encounter ()) then stop No_encounter;
  r.encounters <- r.encounters + 1

(* To the party, or to the PC when the party is full. *)
let caught r species =
  let destination = if r.party < party_size then Party else Pc in
  if not (r.game_steps.finish_catch destination) then
    stop (Failed "the overworld didn't come back after the catch");
  if destination = Party then r.party <- r.party + 1;
  r.caught <- r.caught @ [ { species; destination } ];
  r.game_steps.log
    (Printf.sprintf "Capture: caught %s, to the %s." (species_name species)
       (destination_name destination))

(* The target's battle, from the action menu: balls until caught. *)
let rec target_battle r species turn =
  if turn >= max_turns then
    run_and_stop r (Failed (Printf.sprintf "not caught in %d turns" max_turns))
  else if r.balls >= r.plan.max_balls then run_and_stop r (Out_of_balls None)
  else
    match r.game_steps.throw_ball () with
    | Caught ->
        r.balls <- r.balls + 1;
        caught r species
    | Broke_free ->
        r.balls <- r.balls + 1;
        target_battle r species (turn + 1)
    | No_balls ->
        run_and_stop r (Out_of_balls (Some ("the bag has no " ^ r.plan.ball)))
    | Throw_failed ->
        stop (Failed "the throw didn't end in a catch or at the battle menu")

let is_target (plan : Capture_plan.t) (e : encounter) =
  match plan.target with
  | Species s -> e.species = Some s
  | Uncaught _ -> not e.caught

let log_encounter r (e : encounter) ending =
  r.game_steps.log
    (Printf.sprintf "Capture: encounter %d: %s%s%s." r.encounters
       (species_name e.species)
       (if e.caught then " (caught before)" else "")
       ending)

let run_from r (e : encounter) =
  log_encounter r e ", running";
  if not (r.game_steps.flee ()) then
    stop (Failed ("couldn't run from " ^ species_name e.species))

let battle r =
  let e = r.game_steps.read_encounter () in
  if is_target r.plan e then (
    log_encounter r e "";
    target_battle r e.species 0)
  else run_from r e

let rec catches r =
  if List.length r.caught < r.plan.catches then (
    next_encounter r;
    battle r;
    catches r)

let run game_steps (plan : Capture_plan.t) ~party =
  game_steps.log
    (Printf.sprintf "Capture: %d %s with %s, party of %d." plan.catches
       (Capture_plan.target_name plan.target)
       plan.ball party);
  let r = { game_steps; plan; party; encounters = 0; balls = 0; caught = [] } in
  let end_ =
    match catches r with () -> All_caught | exception Ended end_ -> end_
  in
  { end_; encounters = r.encounters; balls_thrown = r.balls; caught = r.caught }

let end_name = function
  | All_caught -> "caught"
  | Out_of_encounters -> "out_of_encounters"
  | Out_of_balls _ -> "out_of_balls"
  | No_encounter -> "no_encounter"
  | Failed _ -> "failed"

let catch_text (plan : Capture_plan.t) c =
  match plan.target with
  | Species _ -> destination_name c.destination
  | Uncaught _ ->
      Printf.sprintf "%s to the %s"
        (Option.value c.species ~default:"?")
        (destination_name c.destination)

let message (plan : Capture_plan.t) (result : result) =
  let tally =
    Printf.sprintf "%d encounters, %d balls thrown, %d of %d caught"
      result.encounters result.balls_thrown
      (List.length result.caught)
      plan.catches
  in
  let s = Capture_plan.target_name plan.target in
  match result.end_ with
  | All_caught ->
      Printf.sprintf "Capture: caught %d %s (%s): %s." plan.catches s
        (String.concat ", " (List.map (catch_text plan) result.caught))
        tally
  | Out_of_encounters ->
      Printf.sprintf "Capture of %s: out of encounters: %s." s tally
  | Out_of_balls why ->
      Printf.sprintf "Capture of %s: out of balls%s: %s." s
        (match why with Some w -> " (" ^ w ^ ")" | None -> "")
        tally
  | No_encounter ->
      Printf.sprintf "Capture of %s: no wild battle started: %s." s tally
  | Failed detail -> Printf.sprintf "Capture of %s: %s: %s." s detail tally

let party_after party (result : result) =
  List.fold_left
    (fun party c ->
      if c.destination = Party then
        Party_roster.add party (Option.value c.species ~default:"?")
      else party)
    party result.caught
