(** A game's measured times, for scoring plans ({!Route_scorer}). The game sets
    every field; nothing defaults to one game's numbers. *)

type t = {
  ms_per_tile : Direction.t -> run:bool -> int;
      (** Time per tile held in a direction, walking or running. *)
  start_ms : int;  (** From pressing to the first step. *)
  tap_ms : int;  (** One tap and its release. *)
  press_ms : int;  (** A leg's overhead: the turn, the watch. *)
  stop_ms : int;  (** Confirming a stop at a wall (a re-localization). *)
  open_hold_error : (int -> int) option;
      (** How many tiles short or long a held open leg of so many tiles may end.
          [None]: a hold ends exactly. *)
}
