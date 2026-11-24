(* What a checkpoint run shows on the watch page: its events with their states
   and times (each change sends the whole plan, a few hundred bytes) and every
   story line. In the effect context only. *)

open Story
module W = Wire.Watch

type t = { checkpoint : string; events : W.plan_event array }

let show t =
  Effects.show_plan
    { W.checkpoint = t.checkpoint; events = Array.to_list t.events }

let create (checkpoint : Plan.checkpoint) =
  let pending (e : Plan.event) = W.pending e.id in
  let t =
    {
      checkpoint = checkpoint.checkpoint_id;
      events = Array.of_list (List.map pending checkpoint.events);
    }
  in
  show t;
  t

let state_of = function
  | Event_progress.Started -> (W.Current, "")
  | Passed -> (W.Done, "")
  | Skipped flag -> (W.Skipped, flag)
  | Failed reason -> (W.Failed, reason)

let on_event t index progress =
  if index >= 0 && index < Array.length t.events then (
    let state, detail = state_of progress in
    (* Wall time, not the daemon clock: the page shows it across daemons. *)
    let now_ms = int_of_float (Unix.gettimeofday () *. 1000.) in
    t.events.(index) <- W.stamp ~now_ms t.events.(index) state detail;
    show t)

(* The running event as the runner names it in a failure: "#3 talk_clerk". *)
let current t =
  let rec find i =
    if i >= Array.length t.events then None
    else if t.events.(i).state = W.Current || t.events.(i).state = W.Failed then
      Some (Printf.sprintf "#%d %s" (i + 1) t.events.(i).id)
    else find (i + 1)
  in
  find 0

(* A story line to the run's log and to the page. *)
let log base line =
  base line;
  Effects.show_log line
