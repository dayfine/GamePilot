type measurements = Wire.frame
type template_hash = string
type awaited = Holds of measurements | Timeout
type raced = Finished of Wire.batch_done | Stopped of measurements

exception Rpc_error of Wire.error
exception Disconnected of string
exception Stop_requested of string

let () =
  Printexc.register_printer (function
    | Stop_requested reason -> Some reason
    | _ -> None)

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Race : Wire.command list * (measurements -> bool) -> raced Effect.t
  | Race_held : Wire.command list * (measurements -> bool) -> raced Effect.t
  | Replace : Wire.command list -> Wire.batch_done Effect.t
  | Queue : Wire.command list -> unit Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Load_state : string -> int Effect.t
  | Reset : int Effect.t
  | Save_state : string -> int Effect.t
  | Save_frame : string -> int Effect.t
  | Upload_template : string -> template_hash Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t
  | Unsubscribe : string list -> string list Effect.t
  | Show_plan : Wire.Watch.plan -> unit Effect.t
  | Show_log : string -> unit Effect.t
  | Show_run : Wire.Watch_run.t -> unit Effect.t

let submit commands = Effect.perform (Submit commands)
let await ~timeout_ms pred = Effect.perform (Await (pred, timeout_ms))
let race commands ~stop = Effect.perform (Race (commands, stop))

let race_then commands ~stop ~then_ =
  match Effect.perform (Race_held (commands, stop)) with
  | Finished _ as raced -> raced
  | Stopped m as raced ->
      (* [then_] runs here, in the program: it may log or read. *)
      ignore (Effect.perform (Replace (then_ m)) : Wire.batch_done);
      raced

let queue commands = Effect.perform (Queue commands)
let now () = Effect.perform Now
let read () = Effect.perform Read
let load_state path = Effect.perform (Load_state path)
let reset () = Effect.perform Reset
let save_state path = Effect.perform (Save_state path)
let save_frame path = Effect.perform (Save_frame path)
let upload_template png = Effect.perform (Upload_template png)
let subscribe probes = Effect.perform (Subscribe probes)
let unsubscribe ids = Effect.perform (Unsubscribe ids)
let show_plan plan = Effect.perform (Show_plan plan)
let show_log line = Effect.perform (Show_log line)
let show_run run = Effect.perform (Show_run run)
let probe (m : measurements) id = List.assoc_opt id m.probes

(* The folder of the run on this domain, if it keeps one. *)
let run_folder = Domain.DLS.new_key (fun () -> None)

let with_run_folder dir f =
  let outer = Domain.DLS.get run_folder in
  Domain.DLS.set run_folder (Some dir);
  Fun.protect ~finally:(fun () -> Domain.DLS.set run_folder outer) f

let save_run_frame name =
  match Domain.DLS.get run_folder with
  | None -> ()
  | Some dir -> (
      match save_frame (Filename.concat dir name) with
      | (_ : int) -> ()
      | exception Rpc_error _ -> ())

(* The probe ids the [with_probes] calls running on this domain subscribed:
   an inner call leaves the ones an outer call holds to it. *)
let held_ids = Domain.DLS.new_key (fun () -> [])

let first_of_each_id probes =
  List.fold_left
    (fun kept (p : Wire.probe_spec) ->
      if List.exists (fun (k : Wire.probe_spec) -> k.id = p.id) kept then kept
      else kept @ [ p ])
    [] probes

(* The probes of [probes] no running [with_probes] holds, each id once. *)
let not_held probes =
  let held = Domain.DLS.get held_ids in
  List.filter
    (fun (p : Wire.probe_spec) -> not (List.mem p.id held))
    (first_of_each_id probes)

let with_probes probes f =
  let fresh = not_held probes in
  let ids = List.map (fun (p : Wire.probe_spec) -> p.id) fresh in
  let outer = Domain.DLS.get held_ids in
  if ids <> [] then ignore (subscribe fresh : string list);
  Domain.DLS.set held_ids (ids @ outer);
  let release () =
    Domain.DLS.set held_ids outer;
    if ids <> [] then ignore (unsubscribe ids : string list)
  in
  match f () with
  | result ->
      release ();
      result
  | exception (Disconnected _ as e) ->
      Domain.DLS.set held_ids outer;
      raise e
  | exception e ->
      release ();
      raise e
