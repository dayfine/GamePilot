type destination = Party | Pc
type throw_end = Caught | Broke_free | No_balls | Throw_failed

type game_steps = {
  find_encounter : unit -> bool;
  read_encounter : unit -> string option;
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

type result = {
  end_ : end_;
  encounters : int;
  balls_thrown : int;
  caught : destination list;
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
  mutable caught : destination list;
}

exception Ended of end_

let stop end_ = raise (Ended end_)

let run_and_stop r end_ =
  if r.game_steps.flee () then stop end_
  else stop (Failed ("couldn't run from " ^ r.plan.species))

let destination_name = function Party -> "party" | Pc -> "PC"

let next_encounter r =
  if r.encounters >= r.plan.max_encounters then stop Out_of_encounters;
  if r.balls >= r.plan.max_balls then stop (Out_of_balls None);
  if not (r.game_steps.find_encounter ()) then stop No_encounter;
  r.encounters <- r.encounters + 1

(* To the party, or to the PC when the party is full. *)
let caught r =
  let destination = if r.party < party_size then Party else Pc in
  if not (r.game_steps.finish_catch destination) then
    stop (Failed "the overworld didn't come back after the catch");
  if destination = Party then r.party <- r.party + 1;
  r.caught <- r.caught @ [ destination ];
  r.game_steps.log
    (Printf.sprintf "Capture: caught %s, to the %s." r.plan.species
       (destination_name destination))

(* The target's battle, from the action menu: balls until caught. *)
let rec target_battle r turn =
  if turn >= max_turns then
    run_and_stop r (Failed (Printf.sprintf "not caught in %d turns" max_turns))
  else if r.balls >= r.plan.max_balls then run_and_stop r (Out_of_balls None)
  else
    match r.game_steps.throw_ball () with
    | Caught ->
        r.balls <- r.balls + 1;
        caught r
    | Broke_free ->
        r.balls <- r.balls + 1;
        target_battle r (turn + 1)
    | No_balls ->
        run_and_stop r (Out_of_balls (Some "the bag has no Poke Ball"))
    | Throw_failed ->
        stop (Failed "the throw didn't end in a catch or at the battle menu")

let battle r =
  match r.game_steps.read_encounter () with
  | Some species when species = r.plan.species ->
      r.game_steps.log
        (Printf.sprintf "Capture: encounter %d: %s." r.encounters species);
      target_battle r 0
  | seen ->
      let species = Option.value seen ~default:"an unread species" in
      r.game_steps.log
        (Printf.sprintf "Capture: encounter %d: %s, running." r.encounters
           species);
      if not (r.game_steps.flee ()) then
        stop (Failed ("couldn't run from " ^ species))

let rec catches r =
  if List.length r.caught < r.plan.catches then (
    next_encounter r;
    battle r;
    catches r)

let run game_steps (plan : Capture_plan.t) ~party =
  game_steps.log
    (Printf.sprintf "Capture: %d %s, party of %d." plan.catches plan.species
       party);
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

let message (plan : Capture_plan.t) (result : result) =
  let tally =
    Printf.sprintf "%d encounters, %d balls thrown, %d of %d caught"
      result.encounters result.balls_thrown
      (List.length result.caught)
      plan.catches
  in
  let s = plan.species in
  match result.end_ with
  | All_caught ->
      Printf.sprintf "Capture: caught %d %s (%s): %s." plan.catches s
        (String.concat ", " (List.map destination_name result.caught))
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

let party_after party (plan : Capture_plan.t) (result : result) =
  List.fold_left
    (fun party d ->
      if d = Party then Party_roster.add party plan.species else party)
    party result.caught
