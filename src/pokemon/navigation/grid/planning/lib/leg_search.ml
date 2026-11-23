type 'state found = {
  moves : (Direction.t * 'state Leg.step) list;
  end_state : 'state;
  end_facing : Direction.t option;
}

(* A search node: the player, the way they face ([None]: not known), whether
   they are in the middle of a leg that could go on, whether that leg had a
   wild step or crossed a connection, whether it is one step from where a
   hold to a wall ended ([tap_from_wall]), whether such a step was stopped
   after earlier ([tapped]), and its tiles so far, up to
   [Step_model.max_counted_run]. *)
type 'state node = {
  state : 'state;
  facing : Direction.t option;
  moving : bool;
  wild : bool;
  connection : bool;
  tap_from_wall : bool;
  tapped : bool;
  run : int;
}

let start_node state facing =
  {
    state;
    facing;
    moving = false;
    wild = false;
    connection = false;
    tap_from_wall = false;
    tapped = false;
    run = 0;
  }

(* Everything but the state, compared as one tuple. *)
let node_rest n =
  (n.facing, n.moving, n.wild, n.connection, n.tap_from_wall, n.tapped, n.run)

let compare_node compare_state a b =
  match compare_state a.state b.state with
  | 0 -> compare (node_rest a) (node_rest b)
  | order -> order

let risk = function Some f -> f | None -> fun _ _ -> 0

(* The model's tap risk, when the node is one step off a hold to a wall. *)
let tap_risk (model : _ Step_model.t) node facing =
  match model.tap_stop_risk with
  | Some f when node.tap_from_wall && not node.tapped -> f node.state facing
  | _ -> None

let open_cost (model : _ Step_model.t) (costs : Leg_costs.t) node facing next =
  let check =
    match model.open_check_risk with
    | Some f -> f node.state facing ~run:node.run ~next
    | None -> 0
  in
  costs.per_open_stop
  + (if node.wild then costs.per_open_wild_stop else 0)
  + (if node.connection then costs.per_open_connection_stop else 0)
  + risk model.open_stop_risk node.state facing
  + check

(* What stopping at [node] costs, before a leg [next] ([None]: the walk ends
   there). *)
let stop_cost (model : _ Step_model.t) costs node next =
  match node.facing with
  | Some facing when node.moving && not (model.held_at node.state facing) -> (
      match tap_risk model node facing with
      | Some extra -> costs.Leg_costs.per_open_stop + extra
      | None -> open_cost model costs node facing next)
  | _ -> 0

(* Where pressing [direction] from [current] leads. *)
let next_node (model : _ Step_model.t) current direction (step : _ Leg.step) =
  let plain = Option.is_none step.action in
  let extends =
    current.moving
    && current.facing = Some direction
    && plain && not step.starts_leg
  in
  let from_wall =
    match current.facing with
    | Some facing -> current.moving && model.held_at current.state facing
    | None -> false
  in
  {
    state = step.next;
    facing = Some step.facing;
    moving = plain && not step.ends_leg;
    wild = (extends && current.wild) || step.wild;
    connection = (extends && current.connection) || step.connection;
    tap_from_wall = (not extends) && from_wall;
    tapped = current.tapped || ((not extends) && current.tap_from_wall);
    run =
      (if extends then min (current.run + 1) Step_model.max_counted_run else 1);
  }

let step_cost model (costs : Leg_costs.t) current direction (step : _ Leg.step)
    =
  let turn =
    if current.facing = Some direction then 0
    else costs.per_turn + stop_cost model costs current (Some direction)
  in
  costs.per_tile + step.extra_cost + turn

let arrival_cost model (costs : Leg_costs.t) goal_facing node =
  let turn =
    match goal_facing with
    | Some facing when node.facing <> Some facing -> costs.per_turn
    | _ -> 0
  in
  stop_cost model costs node None + turn

(* Queued by cost, then by when queued, so ties go to the first found. *)
module Queue = Map.Make (struct
  type t = int * int

  let compare = compare
end)

(* The cheapest way found to a node so far: its cost, and the press that led
   there from which node ([None] for the start). *)
type 'state entry = {
  cost : int;
  came_from : ('state node * (Direction.t * 'state Leg.step)) option;
}

(* A map from nodes to entries, of whatever map type ['table] the caller
   made for the state's order. *)
type ('state, 'table) nodes = {
  find : 'state node -> 'table -> 'state entry option;
  add : 'state node -> 'state entry -> 'table -> 'table;
}

type ('state, 'table) search = {
  nodes : ('state, 'table) nodes;
  entries : 'table;
  queue : 'state node Queue.t;
  queued : int;
}

let distance_of search node =
  match search.nodes.find node search.entries with
  | Some entry -> entry.cost
  | None -> max_int

(* Records [cost] as the way to [node] if it is cheaper than any so far. *)
let relax node cost came_from search =
  if cost >= distance_of search node then search
  else
    {
      search with
      entries = search.nodes.add node { cost; came_from } search.entries;
      queue = Queue.add (cost, search.queued) node search.queue;
      queued = search.queued + 1;
    }

let expand model costs current cost search =
  let try_direction search direction =
    match model.Step_model.press current.state direction with
    | None -> search
    | Some step ->
        let next = next_node model current direction step in
        let cost = cost + step_cost model costs current direction step in
        relax next cost (Some (current, (direction, step))) search
  in
  List.fold_left try_direction search Direction.all

let better best node total =
  match best with
  | Some (best_total, _) when best_total <= total -> best
  | _ -> Some (total, node)

(* The goal node cheapest to end at, with its total, once nothing cheaper is
   queued. *)
let rec loop model costs ~at_goal ~goal_facing search best =
  let continue = loop model costs ~at_goal ~goal_facing in
  match Queue.min_binding_opt search.queue with
  | None -> (search, best)
  | Some (((cost, _) as key), current) -> (
      let search = { search with queue = Queue.remove key search.queue } in
      match best with
      | _ when cost <> distance_of search current -> continue search best
      | Some (best_total, _) when cost >= best_total -> (search, best)
      | _ when not (at_goal current.state) ->
          continue (expand model costs current cost search) best
      | _ ->
          let total = cost + arrival_cost model costs goal_facing current in
          continue search (better best current total))

let rec moves_to search node moves =
  match search.nodes.find node search.entries with
  | Some { came_from = Some (from, pressed); _ } ->
      moves_to search from (pressed :: moves)
  | _ -> moves

let search_from model costs ~nodes ~empty ~start ~start_facing ~at_goal
    ~goal_facing =
  let first = start_node start start_facing in
  let search = { nodes; entries = empty; queue = Queue.empty; queued = 0 } in
  let search, best =
    loop model costs ~at_goal ~goal_facing (relax first 0 None search) None
  in
  let found (_, finish) =
    {
      moves = moves_to search finish [];
      end_state = finish.state;
      end_facing = finish.facing;
    }
  in
  Option.map found best

let run (type s) (model : s Step_model.t) costs ~start ~start_facing ~at_goal
    ~goal_facing =
  let module Nodes = Map.Make (struct
    type t = s node

    let compare = compare_node model.compare_state
  end) in
  let nodes = { find = Nodes.find_opt; add = Nodes.add } in
  search_from model costs ~nodes ~empty:Nodes.empty ~start ~start_facing
    ~at_goal ~goal_facing
