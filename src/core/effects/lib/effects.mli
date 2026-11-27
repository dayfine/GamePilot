(** The effect set programs may use. Programs call these functions and never
    touch I/O; a handler (real daemon client, replay of a wire log, later a
    simulator) answers them. Every op is direct style: it returns when the
    handler has the answer. *)

type measurements = Wire.frame
(** The latest numbers from the subscribed probes, one per frame: every
    subscribed probe's latest result, also those the frame did not repeat. *)

type template_hash = string
(** An uploaded template as the daemon names it: the lowercase hex SHA-256 of
    its PNG bytes. A [core.template_match@1] probe spec takes it
    ([Wire.template_match_probe]); it is valid for the rest of the connection.
*)

type awaited =
  | Holds of measurements  (** the first frame on which the predicate held *)
  | Timeout

(** How a {!race} ended. *)
type raced =
  | Finished of Wire.batch_done  (** the batch ran to its end *)
  | Stopped of measurements
      (** the first frame on which the stop reader held; the batch was cancelled
          ({!race}) or replaced ({!race_then}) *)

exception Rpc_error of Wire.error
(** The daemon answered a request with an error. *)

exception Disconnected of string
(** The handler lost its source of frames (socket closed, end of log). *)

exception Stop_requested of string
(** Someone pressed Stop on the watch page (the reason): raised by the program's
    next wait on the game ({!submit}, {!race}, {!await}). The daemon already
    released every button. The program ends through its failure path, which may
    still save (saves are not waits). [Printexc.to_string] gives the reason
    alone. *)

(** {1 Effects} *)

type _ Effect.t +=
  | Submit : Wire.command list -> Wire.batch_done Effect.t
  | Submit_at : float * Wire.command list -> Wire.batch_done Effect.t
        (** {!submit_at}: queues one batch starting no earlier than the given
            [start_at_t_ms] on the daemon clock (protocol v1.21). *)
  | Await : (measurements -> bool) * int -> awaited Effect.t
  | Race : Wire.command list * (measurements -> bool) -> raced Effect.t
  | Race_held : Wire.command list * (measurements -> bool) -> raced Effect.t
        (** {!race_then}'s first half: as [Race], but a stopped batch runs on
            until the [Replace] that follows. Programs call {!race_then}. *)
  | Replace : Wire.command list -> Wire.batch_done Effect.t
        (** {!race_then}'s second half: the held batch's queued commands are
            dropped with no release and these run in their place; with none
            held, a plain [Submit]. Programs call {!race_then}. *)
  | Queue : Wire.command list -> unit Effect.t
  | Now : float Effect.t
  | Read : measurements option Effect.t
  | Take_gaps : Wire.gap list Effect.t
        (** {!take_gaps}: drains and returns any [gap] notifications received
            under [delivery: "every"] since the previous call. *)
  | Renew_lease : int option -> unit Effect.t
        (** {!renew_lease}: renews the connection's input lease without sending
            controller input, suppressing keep-awake during long read-only
            waits. *)
  | Load_state : string -> int Effect.t
  | Reset : int Effect.t
  | Save_state : string -> int Effect.t
  | Save_frame : string -> int Effect.t
  | Upload_template : string -> template_hash Effect.t
  | Subscribe : Wire.probe_spec list -> string list Effect.t
  | Unsubscribe : string list -> string list Effect.t
  | Show_plan : Wire.Watch.plan -> unit Effect.t
  | Show_log : string -> unit Effect.t
  | Show_run : Wire.Watch_run.t -> unit Effect.t

(** {1 Ops} *)

val submit : Wire.command list -> Wire.batch_done
(** Queues one batch and returns when its [batch_done] arrives. *)

val submit_at : start_at_t_ms:float -> Wire.command list -> Wire.batch_done
(** Queues one batch starting no earlier than [start_at_t_ms] on the daemon
    clock (protocol v1.21) and returns when its [batch_done] arrives. *)

val await : timeout_ms:int -> (measurements -> bool) -> awaited
(** Returns [Holds m] for the first frame [m] (the latest one included) on which
    the predicate holds, or [Timeout] once a frame is more than [timeout_ms]
    later than [now ()] at the call. *)

val race : Wire.command list -> stop:(measurements -> bool) -> raced
(** Queues one batch and watches the frames while it runs. Returns
    [Finished done] when its [batch_done] arrives first, or [Stopped m] for the
    first frame [m] received after the batch was submitted on which [stop]
    holds. On a stop the handler sends [cancel] (which drops every queued
    command and releases all buttons) and returns once the daemon answered it,
    so the next op starts from released buttons. Frames received before the
    submit, the latest included, are not checked. *)

val race_then :
  Wire.command list ->
  stop:(measurements -> bool) ->
  then_:(measurements -> Wire.command list) ->
  raced
(** As {!race}, but on a stop the batch is replaced, not cancelled: the daemon
    drops the queued commands with no release and runs [then_ m] in their place
    (protocol v1.15, [cancel] with [then]), so a button both hold stays held, as
    the fork's command dispatched over a running one. Returns [Stopped m] once
    that batch is done. Two effects, [Race_held] (stop and leave the batch
    running) then [Replace], so [then_] runs in the program's own context and
    may perform effects (a log line), which a handler's own code could not. *)

val queue : Wire.command list -> unit
(** Queues one batch after the running and queued ones, as {!submit} does, but
    returns once the daemon accepted it, not at its end; its [batch_done] is
    dropped. The program reads and decides while it runs and queues the next
    before it ends: a button held at one batch's end and the next one's start
    stays held, as the fork's commands queued on the controller while the
    program reads (a controller state press,
    NintendoSwitch_Commands_PushButtons.h, then a snapshot; ZL held through the
    PLZA catches, PokemonLZA_AutoStoryCatches.cpp). A later {!submit} or {!race}
    queues after it too; a stop's cancel drops it. *)

val now : unit -> float
(** Daemon clock in ms: the [t_ms] of the newest frame or [batch_done] seen. *)

val read : unit -> measurements option
(** The latest frame, if any arrived since subscribing. *)

val take_gaps : unit -> Wire.gap list
(** Drains and returns any [gap] notifications received since the last call (or
    since the last [load_state] / [reset]), in arrival order. *)

val renew_lease : ?ttl_ms:int -> unit -> unit
(** Renews the connection's input lease via [lease.acquire] without sending
    controller input, keeping the lease active and suppressing keep-awake during
    long read-only waits. Uses the session's configured TTL when [ttl_ms] is
    omitted. *)

(** {1 Setup ops} *)

val load_state : string -> int
(** Loads a save state; returns the frame [seq] after loading. *)

val reset : unit -> int
(** Resets the machine as its power switch would and returns the frame [seq]
    after it, from which the frames count again (mGBA only: the Switch's hard
    reset is closing and starting the game from HOME). The game boots from its
    save, so presses timed from here land on the same frames on every start
    state: the RNG programs' hard reset. *)

val save_state : string -> int
(** Saves the emulator's state to the path; returns the frame [seq] saved. A
    dev-loop op (the checkpoint runner saves a passing checkpoint's end as the
    next one's start), not one a program's steps use. *)

val save_frame : string -> int
(** Writes the current frame to the path as a PNG; returns its [seq]. The
    checkpoint runner's failure frame. *)

val with_run_folder : string -> (unit -> 'a) -> 'a
(** [with_run_folder dir f] runs [f] with [dir] as the run folder that
    {!save_run_frame} writes to, also when [f] raises. The runner calls it
    around a run that keeps a folder (Run_record). *)

val save_run_frame : string -> unit
(** [save_run_frame name] writes the current frame into the run folder as
    [name]: a step keeps the frame it judged (the Mail Glitch's proofs). Outside
    {!with_run_folder} (tests, ctl) it does nothing; a refusal (an older daemon)
    is skipped. *)

val upload_template : string -> template_hash
(** [upload_template png] registers a template from a PNG file's bytes and
    returns its hash. The handler sends each distinct PNG once per connection:
    uploading the same bytes again returns the first hash without a request. *)

val subscribe : Wire.probe_spec list -> string list
(** Subscribes probes; returns the subscribed ids once a frame carried their
    first results (or after a second without one), so a reader that starts right
    after it reads them. *)

val unsubscribe : string list -> string list
(** Stops measuring these probes; returns the ids that were subscribed. The
    latest frame ({!read}) drops their results too. *)

val with_probes : Wire.probe_spec list -> (unit -> 'a) -> 'a
(** [with_probes probes f] subscribes [probes], runs [f] and unsubscribes them,
    also when [f] raises (unless the connection is gone). Calls nest: an inner
    call subscribes only the probes no outer call holds and unsubscribes only
    those, so each phase of a program names every probe its readers need and
    pays for them only while it runs. *)

(** {1 Watch page}

    What the program shows on the watch page beside the video. Neither waits for
    an answer nor goes into the wire log. *)

val show_plan : Wire.Watch.plan -> unit
(** The checkpoint's events and their states, all of them each time. *)

val show_log : string -> unit
(** One story log line. *)

val show_run : Wire.Watch_run.t -> unit
(** The chain of checkpoints and the current one's trials. *)

(** {1 Helpers for readers} *)

val probe : measurements -> string -> Wire.probe_result option
