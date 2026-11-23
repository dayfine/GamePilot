(* Sorts a spread and drops repeated places, so equal sets compare equal. *)
let normalize (model : _ Robust_model.t) spread =
  List.sort_uniq model.compare_state spread

let same_spread (model : _ Robust_model.t) a b =
  List.equal (fun x y -> model.compare_state x y = 0) a b

(* The cheapest way found to a spread so far: its cost, the spread and leg
   that led there ([None] for the start), and whether it is settled. *)
type 'state node = {
  cost : int;
  came_from : ('state list * 'state Robust_leg.t) option;
  settled : bool;
}

(* Queued by cost, then by when queued, so ties go to the first found. *)
module Queue = Map.Make (struct
  type t = int * int

  let compare = compare
end)

(* A map from spreads to nodes, of whatever map type ['table] the caller
   made for the state's order. *)
type ('state, 'table) nodes = {
  find : 'state list -> 'table -> 'state node option;
  add : 'state list -> 'state node -> 'table -> 'table;
}

type ('state, 'table) search = {
  model : 'state Robust_model.t;
  costs : Robust_costs.t;
  nodes : ('state, 'table) nodes;
  table : 'table;
  queue : 'state list Queue.t;
  queued : int;
}

let node search spread = Option.get (search.nodes.find spread search.table)
let leg_into search spread = Option.map snd (node search spread).came_from

(* Whether the leg [before] then [prev] then [leg] is a run to a wall and
   back after a tapped leg along the same axis: the taps left the player on a
   known tile, so running past it and back adds a turn for nothing. From the
   start, after a leg to a wall, or after a perpendicular tapped leg it is how
   a long leg is made fast and exact. *)
let pointless_bounce (before : _ Robust_leg.t) (prev : _ Robust_leg.t)
    (leg : _ Robust_leg.t) =
  prev.to_wall
  && leg.direction = Direction.opposite prev.direction
  && (not before.to_wall)
  && (before.direction = prev.direction || before.direction = leg.direction)

let bounces_back search spread leg =
  match (node search spread).came_from with
  | Some (parent, prev) -> (
      match leg_into search parent with
      | Some before -> pointless_bounce before prev leg
      | None -> false)
  | None -> false

(* What joining the leg to the one into [spread] saves: a leg. *)
let joined_saving search spread leg =
  match leg_into search spread with
  | Some prev when Robust_leg.joins prev leg -> search.costs.per_leg
  | _ -> 0

(* Records [leg] as the way to its spread at [total] if that is cheapest. *)
let record search spread (leg : _ Robust_leg.t) total =
  match search.nodes.find leg.after search.table with
  | Some known when known.cost <= total -> search
  | _ ->
      let entry =
        { cost = total; came_from = Some (spread, leg); settled = false }
      in
      {
        search with
        table = search.nodes.add leg.after entry search.table;
        queue = Queue.add (total, search.queued) leg.after search.queue;
        queued = search.queued + 1;
      }

(* Records the expansion's leg out of [spread] if it is the cheapest way to
   where it leads. Only the start may be wider than
   {!Robust_costs.t.max_spread}: every leg must bring the player within it. *)
let relax search spread cost (expansion : _ Spread_leg.t) =
  let next = normalize search.model expansion.leg.after in
  let leg = { expansion.leg with after = next } in
  if
    List.length next > search.costs.max_spread
    || same_spread search.model next spread
    || bounces_back search spread leg
  then search
  else
    record search spread leg
      (cost + expansion.cost - joined_saving search spread leg)

(* An open leg that ends where the leg to the wall does is that leg: it is
   held until the wall stops the player. *)
let is_wall_leg model (wall : _ Spread_leg.t option) (open_ : _ Spread_leg.t) =
  match wall with
  | Some wall ->
      wall.leg.tiles = open_.leg.tiles
      && same_spread model wall.leg.after open_.leg.after
  | None -> false

(* The open legs that way, 1 tile up to {!Robust_costs.t.max_open_tiles},
   until one is refused. A held leg unsafe at one length may be safe at a
   longer one. *)
let relax_open search spread cost direction wall =
  let is_wall_leg = is_wall_leg search.model wall in
  let rec from tiles search =
    if tiles > search.costs.max_open_tiles then search
    else
      match
        Spread_leg.open_leg search.model search.costs spread direction tiles
      with
      | None -> search
      | Some open_ when is_wall_leg open_ || open_.unsafe ->
          from (tiles + 1) search
      | Some open_ -> from (tiles + 1) (relax search spread cost open_)
  in
  from 1 search

let expand search spread cost =
  let try_direction search direction =
    let wall = Spread_leg.to_wall search.model search.costs spread direction in
    let search =
      match wall with Some w -> relax search spread cost w | None -> search
    in
    relax_open search spread cost direction wall
  in
  List.fold_left try_direction search Direction.all

let rec legs_to search spread legs =
  match (node search spread).came_from with
  | Some (parent, leg) -> legs_to search parent (leg :: legs)
  | None -> legs

let settle search spread found =
  {
    search with
    table = search.nodes.add spread { found with settled = true } search.table;
  }

(* Settles the cheapest queued spread and expands it, until one is at the
   goal. *)
let rec loop search ~at_goal searched =
  match Queue.min_binding_opt search.queue with
  | None -> None
  | Some (((cost, _) as key), spread) ->
      let search = { search with queue = Queue.remove key search.queue } in
      let found = node search spread in
      if found.settled || found.cost <> cost then loop search ~at_goal searched
      else
        visit (settle search spread found) ~at_goal (searched + 1) spread cost

and visit search ~at_goal searched spread cost =
  if searched > search.costs.max_searched then None
  else if List.for_all at_goal spread then
    Some (Robust_leg.consolidate (legs_to search spread []))
  else loop (expand search spread cost) ~at_goal searched

let plan (type s) ?(costs = Robust_costs.default) (model : s Robust_model.t)
    ~from ~at_goal =
  let module Nodes = Map.Make (struct
    type t = s list

    let compare = List.compare model.compare_state
  end) in
  let start = normalize model from in
  let search =
    {
      model;
      costs;
      nodes = { find = Nodes.find_opt; add = Nodes.add };
      table =
        Nodes.singleton start { cost = 0; came_from = None; settled = false };
      queue = Queue.singleton (0, 0) start;
      queued = 1;
    }
  in
  loop search ~at_goal 0

(* What a leg costs when {!plan} would not plan it. *)
let unplanned_cost (costs : Robust_costs.t) (leg : _ Robust_leg.t) =
  let open_extra =
    if leg.to_wall then 0
    else costs.leg_not_at_wall + (costs.per_open_tile * leg.tiles)
  in
  costs.per_leg + (costs.per_tile * leg.tiles) + open_extra

let cost ?(costs = Robust_costs.default) model ~from legs =
  let add (total, spread, previous) (leg : _ Robust_leg.t) =
    let expansion =
      if leg.to_wall then Spread_leg.to_wall model costs spread leg.direction
      else Spread_leg.open_leg model costs spread leg.direction leg.tiles
    in
    let cost =
      match expansion with Some e -> e.cost | None -> unplanned_cost costs leg
    in
    let joined =
      match previous with
      | Some prev when Robust_leg.joins prev leg -> costs.per_leg
      | _ -> 0
    in
    (total + cost - joined, normalize model leg.after, Some leg)
  in
  let total, _, _ = List.fold_left add (0, normalize model from, None) legs in
  total
