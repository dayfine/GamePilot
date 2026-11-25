(** The [status] result (protocol/v1, v1.5): the daemon's health, and which of
    its threads count as stuck. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a [status] result. *)

type thread = {
  name : string;  (** ["capture"], ["server"] *)
  seq : int;  (** the last frame it handled *)
  t_ms : float;  (** when it last showed life, on the daemon clock *)
}
(** One daemon thread's last sign of life, which {!stuck} judges. *)

type t = {
  t_ms : float;  (** when the daemon answered *)
  backend : string;  (** the backend's [kind], as in [hello] *)
  client : string option;
      (** the lease holder's [hello] name, else the oldest connection's *)
  clients : int;  (** connections now *)
  lease : Lease.t option;  (** who may send input; [None] = free *)
  fidelity : string;
      (** ["full"] while an [every] probe is subscribed, else ["latest"] *)
  threads : thread list;  (** the backend's threads, then the server's *)
  ring_depth : int;
      (** frames waiting in the capture ring, between the Switch daemon's
          capture and server threads *)
  ring_capacity : int;
      (** how many frames the ring holds; when full, a push drops the oldest,
          which shows as a gap *)
  gaps : int;  (** jumps in [seq] the server saw *)
  gap_frames : int;  (** frames lost in them *)
}
(** The daemon's health when it answered [status]: what it drives, who is
    connected and holds input, its threads, and its capture ring. *)

val of_json : json -> t
(** A [status] result; a missing or mistyped field is a [Decode_error]. *)

val to_json : t -> json
(** The [status] result, as {!of_json} reads it. *)

val stuck_limit_ms : float
(** How old a thread's heartbeat may be before it counts as stuck: 2 s, for
    every thread. A capture thread beats every 17-33 ms (one frame) and the
    server thread at least every 50 ms, so 2 s is dozens of missed beats, not
    jitter (the design's example limit for capture, PR #44 5.3). *)

val age_ms : t -> thread -> float
(** How long ago [thread] last showed life, as of the reply. *)

val stuck : t -> thread list
(** The threads whose heartbeat is older than {!stuck_limit_ms}. *)
