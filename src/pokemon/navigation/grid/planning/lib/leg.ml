type special_step = ..

type 'state step = {
  next : 'state;
  special_step : special_step option;
  starts_leg : bool;
  ends_leg : bool;
  warped : bool;
  facing : Direction.t;
  extra_cost : int;
  wild : bool;
  connection : bool;
}

let plain_step next facing =
  {
    next;
    special_step = None;
    starts_leg = false;
    ends_leg = false;
    warped = false;
    facing;
    extra_cost = 0;
    wild = false;
    connection = false;
  }

type kind =
  | Walk of { tiles : int; to_wall : bool }
  | Special_step of special_step
  | Face

type 'state t = {
  kind : kind;
  direction : Direction.t;
  warps : bool;
  wild : bool;
  facing_after : Direction.t;
  start : 'state;
  finish : 'state;
}

(* Whether the step walks on along [leg]: a plain step the same way. *)
let extends leg direction step =
  match leg.kind with
  | Walk _ ->
      Option.is_none step.special_step
      && (not step.starts_leg) && leg.direction = direction
  | Special_step _ | Face -> false

let new_leg before direction step =
  let kind =
    match step.special_step with
    | None -> Walk { tiles = 0; to_wall = false }
    | Some special -> Special_step special
  in
  {
    kind;
    direction;
    warps = false;
    wild = false;
    facing_after = step.facing;
    start = before;
    finish = before;
  }

(* [leg] with the step taken: one tile on, and ending where the step does. *)
let take ~held_at leg direction step =
  let kind =
    match leg.kind with
    | Walk { tiles; _ } ->
        let to_wall = (not step.warped) && held_at step.next direction in
        Walk { tiles = tiles + 1; to_wall }
    | (Special_step _ | Face) as kind -> kind
  in
  {
    leg with
    kind;
    warps = step.warped;
    wild = leg.wild || step.wild;
    facing_after = step.facing;
    finish = step.next;
  }

(* The legs so far (last first), whether the last can go on, and where the
   player is. *)
let add ~held_at (legs, can_extend, before) (direction, step) =
  let last, earlier =
    match legs with
    | last :: earlier when can_extend && extends last direction step ->
        (last, earlier)
    | _ -> (new_leg before direction step, legs)
  in
  let leg = take ~held_at last direction step in
  let can_extend = Option.is_none step.special_step && not step.ends_leg in
  (leg :: earlier, can_extend, step.next)

let join ~held_at start moves =
  let legs, _, _ = List.fold_left (add ~held_at) ([], false, start) moves in
  List.rev legs

let face state direction =
  {
    kind = Face;
    direction;
    warps = false;
    wild = false;
    facing_after = direction;
    start = state;
    finish = state;
  }
