type 'state wall_hit = { stop : 'state; tiles : int; held : bool }

let max_steps_to_wall = 1024

let to_wall (model : _ Robust_model.t) from direction =
  let rec slide stop tiles steps =
    if steps >= max_steps_to_wall then { stop; tiles; held = false }
    else
      match model.step stop direction with
      | None -> { stop; tiles; held = model.held_at stop direction }
      | Some next -> slide next (tiles + model.step_tiles stop next) (steps + 1)
  in
  slide from 0 0

type 'state stepped = {
  last : 'state;
  wild : int;
  wander : int;
  along_wander : bool;
}

let start_walk (model : _ Robust_model.t) from =
  ( { last = from; wild = 0; wander = 0; along_wander = false },
    model.wander from )

(* The walk one step on, onto [next], and whether [next] is a wander place. *)
let step_onto (model : _ Robust_model.t) (walk, in_wander) next =
  let next_wander = model.wander next in
  let walk =
    {
      last = next;
      wild = (walk.wild + if model.wild next then 1 else 0);
      wander = (walk.wander + if next_wander then 1 else 0);
      along_wander = walk.along_wander || (next_wander && in_wander);
    }
  in
  (walk, next_wander)

(* What stepping on from where [walk] stopped gives: [`Stopped held] if
   the player is stopped, else the walk one step on and the tiles it counts. *)
let next_step (model : _ Robust_model.t) ((walk, _) as at) direction ~by_tiles =
  match model.step walk.last direction with
  | None -> `Stopped (model.held_at walk.last direction)
  | Some next ->
      let counted = if by_tiles then model.step_tiles walk.last next else 1 in
      `Stepped (step_onto model at next, counted)

let tiles model from direction tiles =
  let rec go ((walk, _) as at) travelled =
    if travelled >= tiles then Some walk
    else
      match next_step model at direction ~by_tiles:true with
      | `Stopped held -> if held then Some walk else None
      | `Stepped (at, counted) -> go at (travelled + counted)
  in
  go (start_walk model from) 0

let prefixes model from direction ~most ~by_tiles =
  let out = Array.make (max most 0) None in
  let fill filled upto value =
    Array.fill out filled (max 0 (upto - filled)) value
  in
  let rec go ((walk, _) as at) filled travelled =
    if filled < most then
      match next_step model at direction ~by_tiles with
      | `Stopped held -> fill filled most (if held then Some walk else None)
      | `Stepped (((walk, _) as at), counted) ->
          let reached = min (travelled + counted) most in
          fill filled reached (Some walk);
          go at (max filled reached) (travelled + counted)
  in
  go (start_walk model from) 0 0;
  out
