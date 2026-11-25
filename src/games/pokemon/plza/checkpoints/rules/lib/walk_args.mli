(** A PLZA walk as a plan writes it: timed legs of the left stick, each an angle
    and a time, and what ends the last one. Ported from the walk's args in
    [PokemonLZA_AutoStoryActionTable.cpp] and [PokemonLZA_AutoStoryWalks.h]
    (fork #754, [plza/mvp-0101]). Positions in PLZA are 3D and camera-relative,
    so a walk is durations and angles, never tiles. The names are ours, not the
    fork's: its [held] is [Steer], its wait is [wait_before_ms] and its
    [end_after_ms] is [earliest_end_ms] (a fork plan file needs those keys
    renamed, [Walk_decode]). Pure: [Walk_decode] reads it from a plan. *)

type leg = {
  angle_deg : float;
      (** Degrees clockwise from where the camera looks (0 straight on, 90
          right). *)
  walk_ms : int;  (** How long the stick is held; 0 for none. *)
}
(** One leg of a walk: an angle, and how long to walk. *)

(** How a move's legs are played. *)
type style =
  | Face_then_walk
      (** A plan's ["face_then_walk"], the default. Each leg first faces its
          angle (a short tilt between two L presses: the camera recentres behind
          the player), then holds the stick straight on. *)
  | Steer
      (** A plan's ["steer"]. Each leg holds the stick at its own angle for its
          time, with an L press before an angled leg after the first. *)

type move = {
  legs : leg list;
  style : style;
  wait_before_ms : int;  (** A wait before anything else; 0 for none. *)
}
(** The legs of a walk, and how they are played. *)

(** The screen event a walk's last leg is held until: [Prompt] an A prompt
    (["A Enter"]), steady 300 ms on. *)
type end_event = Fade_white | Fade_black | Dialog | Prompt

(** What ends a walk's last leg. *)
type until =
  | Scene  (** A scene takes control (text, a box or a fade). *)
  | Event of end_event
  | Talk of { after_legs : bool }
      (** The fork's ["talk"]: A on the A prompt the walk reaches starts a talk.
          [after_legs] (a plan's ["talk_after_legs"], the fork's [to_starter]):
          prompts are passed until every leg is walked. *)

type t = {
  move : move;
  until : until option;
      (** [None]: the legs alone, as timed. Set: the last leg is held, in
          slices, until it. *)
  earliest_end_ms : int;
      (** An end event seen before the last leg has been held this long was
          passed on the way, and the walk goes on; 0 for none. *)
  heading_deg : float option;
      (** The fork's [heading]: a minimap bearing (0 north, 90 east) to face
          before the legs, read from the minimap's arrow. *)
}
(** A walk event's args. *)

val end_event_name : end_event -> string
(** ["fade_white"], ["fade_black"], ["dialog"], ["prompt"]: as a plan writes it.
*)

val end_event_of_name : string -> end_event option
(** {!end_event_name} read back. *)

val style_name : style -> string
(** ["face_then_walk"], ["steer"]: as a plan writes it. *)

val style_of_name : string -> style option
(** {!style_name} read back. *)
