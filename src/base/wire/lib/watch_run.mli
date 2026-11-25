(** The chain a checkpoint run goes through, for the watch page ([watch.run]):
    every checkpoint from [--from] to [--to] with its state, and the trials of
    the current one. The program sends it as a notification at the start and end
    of each run; the daemon keeps the latest for a page that connects later. *)

type json = Yojson.Safe.t
type state = Pending | Current | Passed | Failed | Skipped

type checkpoint = {
  id : string;
  state : state;
  elapsed_ms : int;
      (** Time spent on it, all its runs: so far for the current one (when the
          message was sent), 0 for one not started. *)
}

type t = {
  mode : string;  (** ["testing"] or ["verification"]. *)
  trial : int;
      (** The current checkpoint's run in progress, or the last one when none is
          (1-based; 0 before the first). *)
  trials : int;  (** The runs its policy allows. *)
  passes : int;  (** The current checkpoint's runs that passed so far. *)
  fails : int;
  started_ms : int;  (** When the chain started, Unix time in ms. *)
  checkpoints : checkpoint list;  (** In run order. *)
}

val string_of_state : state -> string
val of_json : json -> t
val to_json : t -> json
