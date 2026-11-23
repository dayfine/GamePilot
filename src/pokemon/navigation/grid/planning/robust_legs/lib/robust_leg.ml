type 'state t = {
  direction : Direction.t;
  tiles : int;
  to_wall : bool;
  after : 'state list;
  held : bool;
}

let joins prev next =
  prev.direction = next.direction
  && (not prev.to_wall) && (not prev.held) && not next.held

let join prev leg =
  {
    prev with
    tiles = prev.tiles + leg.tiles;
    to_wall = leg.to_wall;
    after = leg.after;
  }

let consolidate legs =
  let add consolidated leg =
    match consolidated with
    | prev :: rest when joins prev leg -> join prev leg :: rest
    | _ -> leg :: consolidated
  in
  List.rev (List.fold_left add [] legs)
