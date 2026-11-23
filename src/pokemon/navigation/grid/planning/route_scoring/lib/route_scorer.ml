type replanner = Tile_pos.t list -> Scored_leg.t list option

type scorer = {
  map : Score_map.t;
  paces : Route_paces.t;
  model : Interrupt_model.t;
  goal : Tile_pos.t -> bool;
  replan : replanner option;
  scored : (string, Route_score.t) Hashtbl.t;  (** Recoveries scored. *)
  open_ : (string, unit) Hashtbl.t;  (** Recoveries being scored. *)
  relocalizing : (string, unit) Hashtbl.t;
      (** Of those, the ones whose plan first stops every tile at one wall out
          of harm's way ({!relocalizes}). *)
}

let walk_plan s from legs =
  Plan_walk.walk s.map s.paces s.model ~goal:s.goal from legs

(* Whether [legs] from [unsure] first walk every tile to one wall tile where
   nothing interrupts. A recovery that does is a retry from a known place:
   if it is interrupted where it was before, the walk does the same again,
   each time with the interruption's chance, so it ends. *)
let relocalizes s unsure (legs : Scored_leg.t list) =
  let wall_end first pos =
    let walk = Leg_walk.to_wall s.map s.paces pos first in
    if walk.stop then Some (List.hd walk.ends) else None
  in
  let one_safe_wall = function
    | Some wall :: rest ->
        List.for_all (( = ) (Some wall)) rest && s.map.risk wall = No_risk
    | _ -> false
  in
  match legs with
  | ({ kind = To_wall; _ } as first) :: _ ->
      one_safe_wall (List.map (wall_end first) unsure)
  | _ -> false

(* What an interruption costs on top of the plan: [stop]'s chance times its
   cost and [extra_ms], and the worst case with [extra_worst]. *)
let charge (stop : Plan_walk.interruption) (score : Route_score.t) extra_ms
    extra_worst =
  let cost = float_of_int (stop.cost_ms + extra_ms) in
  {
    score with
    expected_ms = score.expected_ms +. (stop.weight *. stop.chance *. cost);
    worst_ms = max score.worst_ms (score.nominal_ms + stop.cost_ms + extra_worst);
  }

let failed verdict why = Route_score.fail verdict why Route_score.pass

let in_recovery key (score : Route_score.t) =
  if score.verdict = Pass then score
  else { score with why = Printf.sprintf "recovery from %s: %s" key score.why }

(* The plan from where an interruption leaves the player: the rest of the
   interrupted leg, then the legs after it. *)
let rest_of_plan legs (stop : Plan_walk.interruption) =
  let leg : Scored_leg.t = List.nth legs stop.leg in
  let after = List.filteri (fun i _ -> i > stop.leg) legs in
  match leg.kind with
  | To_wall -> leg :: after
  | _ when stop.steps < leg.tiles ->
      { leg with tiles = leg.tiles - stop.steps } :: after
  | _ -> after

(* The tiles an interruption on a leg without a wall may leave the player
   on: a tap lost or one too many either way. *)
let unsure_tiles map (leg : Scored_leg.t) (stop : Plan_walk.interruption) =
  match leg.kind with
  | To_wall -> [ stop.at ]
  | Taps | Open_hold ->
      let one direction = Score_map.walk_steps map stop.at direction ~most:1 in
      (stop.at :: one (Direction.opposite leg.direction)) @ one leg.direction

let rec score_legs s from legs depth =
  let walk = walk_plan s from legs in
  let nominal_ms =
    List.fold_left (fun m (b : Plan_walk.branch) -> max m b.ms) 0 walk.branches
  in
  let score =
    {
      Route_score.pass with
      stops = walk.stops;
      presses = walk.presses;
      nominal_ms;
      worst_ms = nominal_ms;
      expected_ms =
        List.fold_left
          (fun e (b : Plan_walk.branch) -> e +. (b.weight *. float_of_int b.ms))
          0. walk.branches;
    }
  in
  match walk.fail with
  | Some why -> Route_score.fail Fail why score
  | None ->
      List.fold_left
        (fun score stop -> recover s legs stop depth score)
        score walk.interruptions

and recovery_score s unsure depth =
  let key = Plan_walk.key_of unsure in
  if Hashtbl.mem s.open_ key then
    (* A retry from a wall: charged its replan alone ({!recover}). *)
    if Hashtbl.mem s.relocalizing key then Route_score.pass
    else
      failed Strand
        (Printf.sprintf "the recovery from %s leads back to itself" key)
  else
    match Hashtbl.find_opt s.scored key with
    | Some score -> score
    | None -> replanned_score s unsure key depth

and replanned_score s unsure key depth =
  if depth > s.model.max_recoveries then
    failed Retries
      (Printf.sprintf "more than %d recoveries in a row, at %s"
         s.model.max_recoveries key)
  else
    match Option.bind s.replan (fun replan -> replan unsure) with
    | None -> failed Fail (Printf.sprintf "no recovery from %s" key)
    | Some legs ->
        let score = in_recovery key (score_open s unsure key legs depth) in
        Hashtbl.replace s.scored key score;
        score

(* Scores the recovery's [legs] with it marked open, so a recovery that
   leads back into it is seen. *)
and score_open s unsure key legs depth =
  Hashtbl.replace s.open_ key ();
  if relocalizes s unsure legs then Hashtbl.replace s.relocalizing key ();
  let score = score_legs s unsure legs depth in
  Hashtbl.remove s.open_ key;
  Hashtbl.remove s.relocalizing key;
  score

(* Charges an interruption: resuming the plan if its legs absorb where the
   interruption may leave the player, else a new plan from there. *)
and recover s legs (stop : Plan_walk.interruption) depth (score : Route_score.t)
    =
  let score = { score with recoveries = score.recoveries + 1 } in
  let rest = rest_of_plan legs stop in
  let unsure = unsure_tiles s.map (List.nth legs stop.leg) stop in
  match (walk_plan s unsure rest).fail with
  | None ->
      let extra = s.paces.start_ms + s.paces.press_ms in
      charge stop score extra extra
  | Some _ ->
      let score = { score with replans = score.replans + 1 } in
      replan_charge s stop rest unsure depth score

and replan_charge s stop rest unsure depth score =
  let rest_ms =
    match (walk_plan s [ stop.at ] rest).branches with
    | first :: _ -> first.ms
    | [] -> 0
  in
  let again = recovery_score s unsure (depth + 1) in
  let extra ms = max 0 (s.model.replan_ms + ms - rest_ms) in
  match again.verdict with
  | Pass ->
      charge stop score
        (extra (int_of_float again.expected_ms))
        (extra again.worst_ms)
  | verdict ->
      Route_score.fail verdict
        (Printf.sprintf "leg %d interrupted at %s: %s" (stop.leg + 1)
           (Tile_pos.to_string stop.at)
           again.why)
        score

let score ?replan map paces model ~from ~goal legs =
  let s =
    {
      map;
      paces;
      model;
      goal;
      replan;
      scored = Hashtbl.create 8;
      open_ = Hashtbl.create 8;
      relocalizing = Hashtbl.create 8;
    }
  in
  score_legs s from legs 0
