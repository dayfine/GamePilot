(* An effect handler for the walker's tests, in place of a daemon: it answers
   [race], [await] and [now] from a clock of its own, with one frame per ms (so
   the scripted times are exact) on which an interrupt's screen shows from a
   scripted time on. Like the C++ tests' ScriptedLeg, a hold's interrupt shows
   at its scripted time even when that is past the hold's own length: its
   frames run on to it. *)

type t = {
  mutable clock_ms : int;
  mutable seq : int;
  mutable holds_ms : int list;  (** Raced holds, newest first. *)
  mutable hold_script : int option list;
      (** Per hold, in order: how far into it the interrupt shows. *)
  mutable late_script : int option list;
      (** Per [await], in order: how far into it the interrupt shows. *)
  mutable showing : bool;
  mutable cleared : int;
}

let interrupt_probe = "interrupt"

let create ?(late = []) holds =
  {
    clock_ms = 0;
    seq = 0;
    holds_ms = [];
    hold_script = holds;
    late_script = late;
    showing = false;
    cleared = 0;
  }

let showing (m : Effects.measurements) = List.mem_assoc interrupt_probe m.probes

let clear t =
  t.showing <- false;
  t.cleared <- t.cleared + 1

let pop = function [] -> (None, []) | first :: rest -> (first, rest)

let next_frame t ~shows_at i : Wire.frame =
  if Some i = shows_at then t.showing <- true;
  t.clock_ms <- t.clock_ms + 1;
  t.seq <- t.seq + 1;
  let probes =
    if t.showing then [ (interrupt_probe, Wire.Other `Null) ] else []
  in
  { seq = t.seq; t_ms = float_of_int t.clock_ms; probes }

(* Frames for [ms] ms; the first on which [stop] holds, if one does. *)
let run_frames t ~ms ~shows_at stop =
  let rec from i =
    if i > ms then None
    else
      let f = next_frame t ~shows_at i in
      if stop f then Some f else from (i + 1)
  in
  from 1

let batch_ms commands =
  List.fold_left
    (fun total -> function
      | Wire.Press { hold_ms; cooldown_ms; _ } -> total + hold_ms + cooldown_ms
      | Wire.Wait { wait_ms } -> total + wait_ms)
    0 commands

let race t commands stop : Effects.raced =
  let hold_ms = batch_ms commands in
  t.holds_ms <- hold_ms :: t.holds_ms;
  let shows_at, rest = pop t.hold_script in
  t.hold_script <- rest;
  let ms = max hold_ms (Option.value shows_at ~default:0) in
  match run_frames t ~ms ~shows_at stop with
  | Some f -> Stopped f
  | None ->
      Finished
        { batch_id = "scripted"; seq = t.seq; t_ms = float_of_int t.clock_ms }

let await t pred timeout_ms : Effects.awaited =
  let shows_at, rest = pop t.late_script in
  t.late_script <- rest;
  match run_frames t ~ms:timeout_ms ~shows_at pred with
  | Some f -> Holds f
  | None -> Timeout

let run t f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          let answer (v : unit -> a) =
            Some (fun (k : (a, _) continuation) -> continue k (v ()))
          in
          match eff with
          | Effects.Race (commands, stop) ->
              answer (fun () -> race t commands stop)
          | Effects.Await (pred, timeout_ms) ->
              answer (fun () -> await t pred timeout_ms)
          | Effects.Now -> answer (fun () -> float_of_int t.clock_ms)
          | _ -> None);
    }
