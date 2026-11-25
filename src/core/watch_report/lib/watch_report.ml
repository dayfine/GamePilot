module W = Wire.Watch

type t = {
  checkpoint : string;
  events : W.plan_event array;
  mutable mode : string;
  mutable started_ms : int;
}

let ms_per_s = 1000.
let now_ms () = int_of_float (Unix.gettimeofday () *. ms_per_s)

let show t =
  Effects.show_plan
    { W.checkpoint = t.checkpoint; events = Array.to_list t.events }

let create ~checkpoint ids =
  let t =
    {
      checkpoint;
      events = Array.of_list (List.map W.pending ids);
      mode = "";
      started_ms = now_ms ();
    }
  in
  show t;
  t

let set t index state detail =
  if index >= 0 && index < Array.length t.events then (
    t.events.(index) <-
      W.stamp ~now_ms:(now_ms ()) t.events.(index) state detail;
    show t)

let ended (e : W.plan_event) =
  match e.state with
  | W.Pending | Current -> false
  | Done | Failed | Skipped -> true

(* The first step [id] that has not ended; -1 when none (then [set] ignores
   it). *)
let index_of t id =
  let rec find i =
    if i >= Array.length t.events then -1
    else if t.events.(i).id = id && not (ended t.events.(i)) then i
    else find (i + 1)
  in
  find 0

let step t id f =
  let i = index_of t id in
  set t i W.Current "";
  match f () with
  | v ->
      set t i W.Done "";
      v
  | exception e ->
      set t i W.Failed (Printexc.to_string e);
      raise e

let current t =
  let rec find i =
    if i >= Array.length t.events then None
    else if t.events.(i).state = W.Current || t.events.(i).state = W.Failed then
      Some (Printf.sprintf "#%d %s" (i + 1) t.events.(i).id)
    else find (i + 1)
  in
  find 0

let show_run t state ~passes ~fails =
  let now = now_ms () in
  Effects.show_run
    {
      Wire.Watch_run.mode = t.mode;
      trial = 1;
      trials = 1;
      passes;
      fails;
      started_ms = t.started_ms;
      checkpoints =
        [ { id = t.checkpoint; state; elapsed_ms = now - t.started_ms } ];
    }

let start_run t ~mode =
  t.mode <- mode;
  t.started_ms <- now_ms ();
  show_run t Wire.Watch_run.Current ~passes:0 ~fails:0

let end_run t ~passed =
  if passed then show_run t Wire.Watch_run.Passed ~passes:1 ~fails:0
  else show_run t Wire.Watch_run.Failed ~passes:0 ~fails:1

let log base line =
  base line;
  Effects.show_log line
