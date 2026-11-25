(** A line the runner logs, with the game's rules in it kept as values: the
    runner writes its own words and leaves the game's poses and failures to the
    game's text, which prints the line at the edge
    ([Engine_text.Run_text.line]). *)

(** A log line over the game's rules. *)
module Make (T : Engine_rules.GAME_RULES) : sig
  (** One piece of a line. *)
  type part =
    | Text of string  (** The engine's own words, as printed. *)
    | Pose of T.Pose.t  (** A pose, as the game prints it. *)
    | Reason of Failure.Make(T).reason  (** Why an event failed. *)
    | Failure of Failure.Make(T).t  (** Where and why a run stopped. *)

  type t = part list
  (** The pieces, printed one after another. *)
end
