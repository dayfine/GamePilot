(** A scripted console for PLZA's story actions: time passes with each input and
    read, and a scenario's screen is a function of the inputs sent. *)

type input = { at_ms : float; buttons : Wire.button list; stick_ms : int }
(** An input, timed at its end (once released); [stick_ms] how long a stick was
    held with it. *)

type t = {
  mutable now : float;
  mutable inputs : input list;  (** newest first *)
  mutable lines : string list;  (** newest first *)
}

val create : unit -> t

val steps :
  ?party:(t -> int option) ->
  t ->
  (t -> Plza_story.Story_look.t) ->
  Plza_story.Story_steps.game_steps
(** The story steps on it; each read advances 33 ms then asks the screen. A
    party count advances two reads and asks [party] (default: none read). *)

val nth_after : t -> Wire.button -> after:float -> int -> float option
(** The [n]th press of the button (from 0) ended after [after]. *)

val last_press : t -> Wire.button -> float option
(** When the last press of the button ended. *)

val stick_reached : t -> int -> float option
(** When the stick, held in all, reached that many ms. *)

val lines : t -> string list
(** What was logged, oldest first. *)
