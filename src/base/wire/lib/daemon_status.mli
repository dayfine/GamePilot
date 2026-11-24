(** The [status] result (contracts/v1, v1.5): the daemon's health, and which of
    its threads count as stuck. *)

type json = Yojson.Safe.t

type thread = {
  name : string;  (** ["capture"], ["server"] *)
  seq : int;  (** the last frame it handled *)
  t_ms : float;  (** when it last showed life, on the daemon clock *)
}

type t = {
  t_ms : float;  (** when the daemon answered *)
  backend : string;
  client : string option;
      (** the lease holder's [hello] name, else the oldest connection's *)
  clients : int;  (** connections now *)
  lease : Lease.t option;  (** who may send input; [None] = free *)
  fidelity : string;  (** ["full"] or ["latest"] *)
  threads : thread list;
  ring_depth : int;
  ring_capacity : int;
  gaps : int;  (** jumps in [seq] the server saw *)
  gap_frames : int;  (** frames lost in them *)
}

val of_json : json -> t
val to_json : t -> json

val stuck_limit_ms : float
(** How old a thread's heartbeat may be before it counts as stuck: 2 s, for
    every thread. A capture thread beats every 17-33 ms (one frame) and the
    server thread at least every 50 ms, so 2 s is dozens of missed beats, not
    jitter (the design's example limit for capture, PR #44 5.3). *)

val age_ms : t -> thread -> float
(** How long ago [thread] last showed life, as of the reply. *)

val stuck : t -> thread list
(** The threads whose heartbeat is older than {!stuck_limit_ms}. *)
