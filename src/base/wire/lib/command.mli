(** Button commands, their batches, and the [submit] and [cancel] results. *)

type json = Yojson.Safe.t
type button = A | B | Select | Start | Right | Left | Up | Down | R | L

val string_of_button : button -> string
val button_of_string : string -> button option

type command =
  | Press of { buttons : button list; hold_ms : int; cooldown_ms : int }
  | Wait of { wait_ms : int }

val command_of_json : json -> command
val json_of_command : command -> json

type batch_done = { batch_id : string; seq : int; t_ms : float }

val batch_done_of_json : json -> batch_done
val json_of_batch_done : batch_done -> json

type submit_result = { batch_id : string; start_seq : int }

val submit_result_of_json : json -> submit_result
val json_of_submit_result : submit_result -> json

val cancel_result_of_json : json -> int
(** The [released_seq]. *)

val json_of_cancel_result : int -> json
