type measurements = Wire.frame
type template_hash = string
type awaited = Holds of measurements | Timeout
type raced = Finished of Wire.batch_done | Stopped of measurements

exception Rpc_error of Wire.error
exception Disconnected of string

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Race : Wire.command list * (measurements -> bool) -> raced Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Load_state : string -> int Effect.t
  | Upload_template : string -> template_hash Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t

let submit commands = Effect.perform (Submit commands)
let await ~timeout_ms pred = Effect.perform (Await (pred, timeout_ms))
let race commands ~stop = Effect.perform (Race (commands, stop))
let now () = Effect.perform Now
let read () = Effect.perform Read
let load_state path = Effect.perform (Load_state path)
let upload_template png = Effect.perform (Upload_template png)
let subscribe probes = Effect.perform (Subscribe probes)
let probe (m : measurements) id = List.assoc_opt id m.probes
