open Blink_extraction

type estimate = {
  threshold : float option;
  samples : int;  (** Samples it was estimated from. *)
}

type t = { estimates : estimate list; frozen : float list option }

let start ~watchers =
  {
    estimates = List.init watchers (fun _ -> { threshold = None; samples = 0 });
    frozen = None;
  }

(* The estimate is redone when the sample count has moved by a quarter. *)
let quarter = 4

let estimate_for estimate samples =
  let held = List.length samples and counted = estimate.samples in
  if
    estimate.threshold = None
    || held >= counted + (counted / quarter)
    || counted >= held + (held / quarter)
  then { threshold = auto_blink_threshold samples; samples = held }
  else estimate

let rec estimate_all estimates matches found =
  match (estimates, matches) with
  | estimate :: estimates, samples :: matches ->
      estimate_next (estimate_for estimate samples) estimates matches found
  | estimates, _ -> (estimates, Some (List.rev found))

and estimate_next estimate estimates matches found =
  match estimate.threshold with
  | Some threshold when threshold > 0.0 ->
      let rest, thresholds =
        estimate_all estimates matches (threshold :: found)
      in
      (estimate :: rest, thresholds)
  | _ -> (estimate :: estimates, None)

let thresholds state matches =
  match state.frozen with
  | Some frozen -> (state, Some frozen)
  | None ->
      let estimates, thresholds = estimate_all state.estimates matches [] in
      ({ state with estimates }, thresholds)

let freeze state thresholds =
  match state.frozen with
  | Some _ -> state
  | None -> { state with frozen = Some thresholds }

let frozen state = state.frozen
