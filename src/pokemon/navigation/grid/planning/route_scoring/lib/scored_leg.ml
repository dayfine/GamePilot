type kind = To_wall | Taps | Open_hold
type t = { direction : Direction.t; tiles : int; kind : kind; run : bool }

let to_string leg =
  let how =
    match (leg.kind, leg.run) with
    | To_wall, true -> "run to wall"
    | To_wall, false -> "walk to wall"
    | Open_hold, true -> "run, open"
    | Open_hold, false -> "walk, open"
    | Taps, _ -> "taps"
  in
  Printf.sprintf "%s %d (%s)" (Direction.name leg.direction) leg.tiles how

let tiles_walked_back legs =
  let back_tiles (tiles, before) leg =
    let back = Direction.opposite leg.direction in
    let after_wall_back =
      match before with
      | prev :: _ -> prev.kind = To_wall && prev.direction = back
      | [] -> false
    in
    let walks_back =
      (not after_wall_back) && List.exists (fun l -> l.direction = back) before
    in
    ((if walks_back then tiles + leg.tiles else tiles), leg :: before)
  in
  fst (List.fold_left back_tiles (0, []) legs)
