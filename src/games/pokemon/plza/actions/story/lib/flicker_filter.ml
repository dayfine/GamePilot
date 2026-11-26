type t = {
  hits : int;
  window_ms : float;
  off_after_ms : float;
  mutable seen : float list;  (** oldest first *)
  mutable on : bool;
}

let make ~hits ~window_ms ~off_after_ms =
  { hits; window_ms; off_after_ms; seen = []; on = false }

let battle_hits = 2
let battle_window_ms = 2000.0
let battle_off_after_ms = 3000.0

let battle_hud () =
  make ~hits:battle_hits ~window_ms:battle_window_ms
    ~off_after_ms:battle_off_after_ms

let last = function [] -> None | l -> Some (List.nth l (List.length l - 1))

let on_with t seen at_ms =
  if seen then
    let recent =
      List.length (List.filter (fun at -> at_ms -. at <= t.window_ms) t.seen)
    in
    t.on || recent + 1 >= t.hits
  else
    match last t.seen with
    | Some at -> t.on && at_ms -. at < t.off_after_ms
    | None -> false

(* Drops the oldest reads out of the window, keeping the last one. *)
let rec pruned t at_ms = function
  | first :: (_ :: _ as rest) when at_ms -. first > t.window_ms ->
      pruned t at_ms rest
  | seen -> seen

let record t seen at_ms =
  t.on <- on_with t seen at_ms;
  if seen then t.seen <- t.seen @ [ at_ms ];
  t.seen <- pruned t at_ms t.seen
