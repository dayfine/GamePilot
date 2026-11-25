type t = {
  hold : int;
  sliced : int;
  elapsed : int;
  first : (float * int) option;  (** The first read's time and its slice. *)
  last_read : float;
  clock_runs : bool;
}

let start hold =
  {
    hold;
    sliced = 0;
    elapsed = 0;
    first = None;
    last_read = Float.neg_infinity;
    clock_runs = false;
  }

let unfinished h = h.sliced < h.hold || (h.clock_runs && h.elapsed < h.hold)
let sliced_ms h = h.sliced
let elapsed_ms h = max h.elapsed h.hold

let add_slice h slice ~read_at =
  let first, clock_runs =
    match h.first with
    | None -> ((read_at, slice), h.clock_runs)
    | Some first -> (first, read_at > h.last_read)
  in
  let first_read, first_slice = first in
  {
    h with
    sliced = h.sliced + slice;
    first = Some first;
    last_read = read_at;
    clock_runs;
    elapsed = first_slice + int_of_float (read_at -. first_read);
  }
