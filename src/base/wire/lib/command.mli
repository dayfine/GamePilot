(** Button commands, their batches, and the [submit] and [cancel] results. *)

type json = Yojson.Safe.t

type button =
  | A
  | B
  | Select
  | Start
  | Right
  | Left
  | Up
  | Down
  | R
  | L
  | Home  (** The Switch only, as are [X] and [Y] (protocol v1.11). *)
  | X
  | Y

val string_of_button : button -> string
val button_of_string : string -> button option

val switch_only : button -> bool
(** [Home], [X] and [Y]: the daemon refuses them on any backend but the Switch.
*)

type stick = private float * float
(** A stick's tilt [(x, y)], each in -1..1, as CoreLib's [JoystickPosition]: [x]
    +1 is right, [y] +1 is up, [(0., 0.)] centred (protocol v1.12). *)

val stick : float -> float -> (stick, string) result
(** [stick x y]; an error when [x] or [y] is outside -1..1 or not a number. *)

type command =
  | Press of {
      buttons : button list;  (** may be empty when a stick is tilted *)
      left_stick : stick option;
      right_stick : stick option;
      hold_ms : int;
      cooldown_ms : int;
    }
      (** Holds [buttons] and tilts the sticks for [hold_ms], then releases and
          centres everything for [cooldown_ms]. A stick left out ([None]) is
          centred and is not on the wire; the daemon refuses a tilted stick on
          any backend but the Switch (v1.12). *)
  | Wait of { wait_ms : int }

val press :
  ?left_stick:stick ->
  ?right_stick:stick ->
  hold_ms:int ->
  cooldown_ms:int ->
  button list ->
  command
(** [press ~hold_ms ~cooldown_ms buttons] is a {!Press}; each stick is centred
    ([None]) unless given. *)

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
