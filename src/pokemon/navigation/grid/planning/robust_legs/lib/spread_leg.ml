type 'state t = { cost : int; leg : 'state Robust_leg.t; unsafe : bool }

(* The most wild and wander places any one walk of the leg enters. *)
type risks = { wild : int; wander : int }

let no_risks = { wild = 0; wander = 0 }

let worst risks (walk : _ Straight_walk.stepped) =
  { wild = max risks.wild walk.wild; wander = max risks.wander walk.wander }

let refused (costs : Robust_costs.t) (walk : _ Straight_walk.stepped) =
  costs.forbid_along_wander && walk.along_wander

(* Folds [f] over the spread, stopping at the first [None]. *)
let fold_spread f init spread =
  List.fold_left (fun acc place -> Option.bind acc (f place)) (Some init) spread

(* The risks of one place's walk to the wall, added to [risks]; [None] if
   the walk is refused. *)
let wall_walk_risks model costs place direction (hit : _ Straight_walk.wall_hit)
    risks =
  match Straight_walk.tiles model place direction hit.tiles with
  | Some walk when refused costs walk -> None
  | Some walk -> Some (worst risks walk)
  | None -> Some risks

let wall_cost (costs : Robust_costs.t) longest risks =
  costs.per_leg + (costs.per_tile * longest)
  + (costs.per_wild_tile * risks.wild)
  + (costs.per_wander_tile * risks.wander)

let leg_of direction ~tiles ~to_wall ~held after =
  { Robust_leg.direction; tiles; to_wall; after = List.rev after; held }

(* One place's walk to the wall, added to the walks so far. *)
let wall_walk model costs direction place (risks, longest, after) =
  let hit = Straight_walk.to_wall model place direction in
  let add risks = (risks, max longest hit.tiles, hit.stop :: after) in
  if not hit.held then None
  else Option.map add (wall_walk_risks model costs place direction hit risks)

let to_wall model (costs : Robust_costs.t) spread direction =
  match
    fold_spread (wall_walk model costs direction) (no_risks, 0, []) spread
  with
  | None | Some (_, 0, _) -> None
  | Some (risks, tiles, after) ->
      let leg = leg_of direction ~tiles ~to_wall:true ~held:false after in
      Some { cost = wall_cost costs tiles risks; leg; unsafe = false }

(* Whether a held leg's possible ends, in order from the shortest, meet
   nothing past the shortest that a tap would not: no wild or wander place,
   no ledge hop. *)
let held_ends_safe (model : _ Robust_model.t) ends =
  let rec safe = function
    | a :: (b :: _ as rest) ->
        model.step_tiles a b <= 1
        && (not (model.wild b))
        && (not (model.wander b))
        && safe rest
    | [ _ ] | [] -> true
  in
  safe ends

(* The possible ends of one place's open leg, shortest first, and the
   risks so far; [None] if one is refused. *)
let open_ends model (costs : Robust_costs.t) place direction tiles ~error ~held
    risks =
  let prefixes =
    Straight_walk.prefixes model place direction ~most:(tiles + error)
      ~by_tiles:held
  in
  let rec ends n risks acc =
    if n > tiles + error then Some (List.rev acc, risks)
    else
      match prefixes.(n - 1) with
      | Some walk when not (refused costs walk) ->
          ends (n + 1) (worst risks walk) (walk.Straight_walk.last :: acc)
      | Some _ | None -> None
  in
  ends (max 1 (tiles - error)) risks []

let open_cost (costs : Robust_costs.t) tiles ~held risks =
  let per_open_tile = if held then 0 else costs.per_open_tile in
  costs.per_leg + costs.leg_not_at_wall
  + ((costs.per_tile + per_open_tile) * tiles)
  + ((costs.per_wild_tile + costs.per_open_wild_tile) * risks.wild)
  + (costs.per_wander_tile * risks.wander)

let open_leg model (costs : Robust_costs.t) spread direction tiles =
  let error = Robust_costs.open_leg_error costs tiles in
  let held = costs.hold_open_legs && error > 0 in
  let add_ends unsafe after (ends, risks) =
    let unsafe = unsafe || (held && not (held_ends_safe model ends)) in
    (risks, unsafe, List.rev_append ends after)
  in
  let walk_one place (risks, unsafe, after) =
    open_ends model costs place direction tiles ~error ~held risks
    |> Option.map (add_ends unsafe after)
  in
  let expansion (risks, unsafe, after) =
    let leg = leg_of direction ~tiles ~to_wall:false ~held after in
    { cost = open_cost costs tiles ~held risks; leg; unsafe }
  in
  fold_spread walk_one (no_risks, false, []) spread |> Option.map expansion
