type branch = { pos : Tile_pos.t; ms : int; weight : float; sighted : bool }

type interruption = {
  leg : int;
  steps : int;
  at : Tile_pos.t;
  chance : float;
  cost_ms : int;
  weight : float;
}

type t = {
  branches : branch list;
  interruptions : interruption list;
  stops : int;
  presses : int;
  fail : string option;
}

module Branches = Map.Make (String)

let key_of tiles =
  let by_row (a : Tile_pos.t) (b : Tile_pos.t) =
    compare (a.y, a.x) (b.y, b.x)
  in
  String.concat "" (List.map Tile_pos.to_string (List.sort by_row tiles))

let first_fail walk why =
  match walk.fail with Some _ -> walk | None -> { walk with fail = Some why }

(* The interruption that stepping onto [at] may bring, if any, and the
   branch after it: a trainer sees the player once. *)
let interruption_at (map : Score_map.t) (model : Interrupt_model.t)
    (branch : branch) ~leg ~steps at =
  let stop chance cost_ms =
    Some { leg; steps; at; chance; cost_ms; weight = branch.weight }
  in
  match map.risk at with
  | Encounter -> (stop model.encounter_per_tile model.encounter_ms, branch)
  | Wanderer -> (stop model.wanderer_per_tile model.wanderer_ms, branch)
  | Sight ->
      ( stop (if branch.sighted then 0. else 1.) model.trainer_ms,
        { branch with sighted = true } )
  | No_risk | Warp | Trigger -> (None, branch)

(* The interruptions along a leg's path, appended to [walk]'s, and the branch
   after them. *)
let add_interruptions map model ~leg (path : Tile_pos.t list) walk branch =
  let add (found, branch, steps) at =
    let stop, branch = interruption_at map model branch ~leg ~steps at in
    let found =
      match stop with
      | Some stop when stop.chance > 0. -> stop :: found
      | Some _ | None -> found
    in
    (found, branch, steps + 1)
  in
  let found, branch, _ = List.fold_left add ([], branch, 1) path in
  ({ walk with interruptions = walk.interruptions @ List.rev found }, branch)

let warp_fail (map : Score_map.t) ~goal ~last ~leg_name ~from path =
  let final = match List.rev path with p :: _ -> Some p | [] -> None in
  let into_goal pos = last && Some pos = final && goal pos in
  List.find_opt (fun pos -> map.risk pos = Warp && not (into_goal pos)) path
  |> Option.map (fun pos ->
         Printf.sprintf "%s from %s walks into the warp at %s" leg_name from
           (Tile_pos.to_string pos))

(* Two ways to the same tile: their chances add, the slower time counts. *)
let merge (known : branch) (b : branch) =
  { known with weight = known.weight +. b.weight; ms = max known.ms b.ms }

let merge_end (walked : branch) n next end_ =
  let b = { walked with pos = end_; weight = walked.weight /. n } in
  let add = function None -> Some b | Some known -> Some (merge known b) in
  Branches.update (key_of [ end_ ]) add next

(* The leg's failures from one branch, added to [walk]'s. *)
let leg_fails map ~goal ~last ~index (leg : Scored_leg.t) (branch : branch)
    (leg_walk : Leg_walk.t) walk =
  let leg_name =
    Printf.sprintf "leg %d (%s)" (index + 1) (Scored_leg.to_string leg)
  in
  let from = Tile_pos.to_string branch.pos in
  let overshoot hazard =
    Printf.sprintf "%s from %s may overshoot onto %s" leg_name from hazard
  in
  let fails =
    [
      Option.map overshoot leg_walk.unsafe;
      warp_fail map ~goal ~last ~leg_name ~from leg_walk.path;
    ]
  in
  List.fold_left first_fail walk (List.filter_map Fun.id fails)

let walk_branch map paces model ~goal ~index ~last (leg : Scored_leg.t)
    (walk, next) (branch : branch) =
  let leg_walk = Leg_walk.walk map paces ~goal branch.pos leg in
  let walk = leg_fails map ~goal ~last ~index leg branch leg_walk walk in
  let walked = { branch with ms = branch.ms + leg_walk.ms } in
  let walk, walked =
    add_interruptions map model ~leg:index leg_walk.path walk walked
  in
  let n = float_of_int (List.length leg_walk.ends) in
  (walk, List.fold_left (merge_end walked n) next leg_walk.ends)

let walk_leg map paces (model : Interrupt_model.t) ~goal ~count walk index
    (leg : Scored_leg.t) =
  let walk, next =
    List.fold_left
      (walk_branch map paces model ~goal ~index ~last:(index + 1 = count) leg)
      (walk, Branches.empty) walk.branches
  in
  let branches = List.map snd (Branches.bindings next) in
  let walk =
    {
      walk with
      branches;
      presses = (walk.presses + match leg.kind with Taps -> leg.tiles | _ -> 1);
      stops = (walk.stops + match leg.kind with To_wall -> 1 | _ -> 0);
    }
  in
  if List.length branches > model.max_spread then
    first_fail walk
      (Printf.sprintf "after leg %d the player may be on %d tiles" (index + 1)
         (List.length branches))
  else walk

let walk map paces model ~goal from legs =
  let weight = 1. /. float_of_int (List.length from) in
  let start =
    {
      branches =
        List.map (fun pos -> { pos; ms = 0; weight; sighted = false }) from;
      interruptions = [];
      stops = 0;
      presses = 0;
      fail = None;
    }
  in
  let count = List.length legs in
  let walked =
    List.fold_left
      (fun (walk, index) (leg : Scored_leg.t) ->
        (walk_leg map paces model ~goal ~count walk index leg, index + 1))
      (start, 0) legs
    |> fst
  in
  match List.find_opt (fun b -> not (goal b.pos)) walked.branches with
  | Some off ->
      first_fail walked
        (Printf.sprintf "may end on %s, off the goal"
           (Tile_pos.to_string off.pos))
  | None -> walked
