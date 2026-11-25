type t = {
  hold : int;
  sliced : int;
  elapsed : int;
  first : (float * int) option;  (** The first look's time and its slice. *)
  last_look : float;
  clock_runs : bool;
}

let start hold =
  {
    hold;
    sliced = 0;
    elapsed = 0;
    first = None;
    last_look = Float.neg_infinity;
    clock_runs = false;
  }

let holding h = h.sliced < h.hold || (h.clock_runs && h.elapsed < h.hold)
let sliced h = h.sliced
let elapsed h = max h.elapsed h.hold

let held_slice h slice ~look_at =
  let first, clock_runs =
    match h.first with
    | None -> ((look_at, slice), h.clock_runs)
    | Some first -> (first, look_at > h.last_look)
  in
  let first_look, first_slice = first in
  {
    h with
    sliced = h.sliced + slice;
    first = Some first;
    last_look = look_at;
    clock_runs;
    elapsed = first_slice + int_of_float (look_at -. first_look);
  }
