(** The chain a checkpoint run goes through, for the watch page ([watch.run]):
    every checkpoint from [--from] to [--to] with its state, and the trials of
    the current one. The program sends it as a notification at the start and end
    of each run; the daemon keeps the latest for a page that connects later. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a [watch.run] notification's params. *)

(** Where a checkpoint of the chain stands. *)
type state =
  | Pending  (** not started yet *)
  | Current  (** running now *)
  | Passed  (** its trials passed *)
  | Failed  (** its trials failed, which ends the chain *)
  | Skipped  (** never run: an earlier checkpoint failed *)

type checkpoint = {
  id : string;  (** the checkpoint's id, as [--from] and [--to] name it *)
  state : state;
  elapsed_ms : int;
      (** Time spent on it, all its runs: so far for the current one (when the
          message was sent), 0 for one not started. *)
}
(** One checkpoint of the chain, its state and the time spent on it. *)

type t = {
  mode : string;  (** ["testing"] or ["verification"]. *)
  trial : int;
      (** The current checkpoint's run in progress, or the last one when none is
          (1-based; 0 before the first). *)
  trials : int;  (** The runs its policy allows. *)
  passes : int;  (** The current checkpoint's runs that passed so far. *)
  fails : int;  (** The current checkpoint's runs that failed so far. *)
  started_ms : int;  (** When the chain started, Unix time in ms. *)
  checkpoints : checkpoint list;  (** In run order. *)
}
(** A [watch.run] notification: the chain, its trial policy, and how the current
    checkpoint's runs went. *)

val string_of_state : state -> string
(** The state's name on the wire: ["pending"], ["current"], ["passed"],
    ["failed"] or ["skipped"]. *)

val of_json : json -> t
(** A [watch.run] notification's params; a missing field or an unknown state is
    a [Decode_error]. *)

val to_json : t -> json
(** A [watch.run] notification's params, as {!of_json} reads them. *)
