(** Button commands, their batches, and the [submit] and [cancel] results. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a command, a notification's params or a result. *)

(** A controller button a command presses, named on the wire as here (["A"],
    ["LStick"]). The first ten are the GBA's, which every backend has; the rest
    are the Switch's (see {!switch_only}). *)
type button =
  | A  (** the A button: confirm, talk *)
  | B  (** the B button: back, cancel *)
  | Select  (** the Select button *)
  | Start  (** the Start button, which opens a game's start menu *)
  | Right  (** the D-pad's right *)
  | Left  (** the D-pad's left *)
  | Up  (** the D-pad's up *)
  | Down  (** the D-pad's down *)
  | R  (** the right shoulder button *)
  | L  (** the left shoulder button *)
  | Home  (** the Switch's HOME button (protocol v1.11) *)
  | X  (** the Switch's X *)
  | Y  (** the Switch's Y *)
  | ZL  (** the Switch's left trigger *)
  | ZR  (** the Switch's right trigger *)
  | Plus  (** the Switch's + *)
  | Minus  (** the Switch's - *)
  | LStick  (** a click of the Switch's left stick *)

val all_buttons : button list
(** Every button, in the daemon's bit order (protocol/v1). *)

val string_of_button : button -> string
(** The button's name on the wire, the constructor's own (["ZL"]). *)

val button_of_string : string -> button option
(** The button a wire name stands for; [None] for an unknown name. *)

val switch_only : button -> bool
(** [Home], [X], [Y], [ZL], [ZR], [Plus], [Minus] and [LStick] (the left stick's
    click): the daemon refuses them on any backend but the Switch. *)

type stick = private float * float
(** A stick's tilt [(x, y)], each in -1..1, as CoreLib's [JoystickPosition]: [x]
    +1 is right, [y] +1 is up, [(0., 0.)] centred (protocol v1.12). *)

val stick : float -> float -> (stick, string) result
(** [stick x y]; an error when [x] or [y] is outside -1..1 or not a number. *)

(** One step of a [submit] batch, which the daemon runs in order. *)
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
      (** Presses nothing for [wait_ms], everything released. *)

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
(** One command of a batch: [{"press": [...], "hold_ms", "cooldown_ms"}] with
    optional sticks, or [{"wait_ms"}]; anything else, an unknown button or a
    stick out of range is a [Decode_error]. *)

val json_of_command : command -> json
(** One command, as {!command_of_json} reads it. *)

type batch_done = { batch_id : string; seq : int; t_ms : float }
(** A [batch_done] notification: the batch [batch_id] has run all its commands,
    as of frame [seq] at [t_ms] on the daemon clock. *)

val batch_done_of_json : json -> batch_done
(** A [batch_done] notification's params; a missing field is a [Decode_error].
*)

val json_of_batch_done : batch_done -> json
(** A [batch_done] notification's params, as {!batch_done_of_json} reads them.
*)

type submit_result = { batch_id : string; start_seq : int }
(** The answer to [submit]: the batch taken, and [start_seq], the frame it
    starts on (after the batches queued before it on a frame-stepped backend,
    the current frame on a live one). *)

val submit_result_of_json : json -> submit_result
(** The [submit] result; a missing field is a [Decode_error]. *)

val json_of_submit_result : submit_result -> json
(** The [submit] result, as {!submit_result_of_json} reads it. *)

val cancel_result_of_json : json -> int
(** The [cancel] result's [released_seq]: the frame on which every button was
    released. *)

val json_of_cancel_result : int -> json
(** The [cancel] result, [{"released_seq": n}]. *)
