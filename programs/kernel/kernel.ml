type measurements = Wire.frame
type awaited = Holds of measurements | Timeout

exception Rpc_error of Wire.error
exception Disconnected of string

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Load_state : string -> int Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t

let submit commands = Effect.perform (Submit commands)
let await ~timeout_ms pred = Effect.perform (Await (pred, timeout_ms))
let now () = Effect.perform Now
let read () = Effect.perform Read
let load_state path = Effect.perform (Load_state path)
let subscribe probes = Effect.perform (Subscribe probes)
let probe (m : measurements) id = List.assoc_opt id m.probes
