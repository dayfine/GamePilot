(** The daemon for one checkpoint run: started with its wire log in the run's
    folder, stopped (SIGTERM, which it handles by closing cleanly) after the
    run. One daemon per run gives each run its own wire log, which
    [gamepilot replay checkpoint] replays as it is. Port 0 lets the daemon pick
    a free one; [t] has the ports it bound, read from its output. *)

type t = {
  pid : int;
  out_file : string;
  port : int;  (** the program's, as bound *)
  watch_port : int option;  (** the watch page's, as bound *)
}

(** Where the Switch's frames come from: the capture card, or a recorded video
    (a dry run). *)
type frames = Capture of string | Replay of string

(** What the daemon drives: mGBA through its bridge, or the Switch through the
    controller board's serial port and the capture card (names as
    [gamepilot switch-devices] prints them). With no serial port the daemon
    sends the presses to its fake board: a dry run. *)
type backend =
  | Mgba of { port : int }
  | Switch of { serial : string option; frames : frames }

type watch = {
  listen : string;
      (** The address it binds: [127.0.0.1] unless the user opened it to the
          LAN. *)
  port : int;  (** 0: any free port. *)
  token : string;  (** Stop's (Watch_urls.new_token), the same for a series. *)
  registry : string;  (** The watch registry folder ($GAMEPILOT_RUNS/.watch). *)
}

val frames_args : frames -> string list
(** [--capture DEVICE] or [--replay VIDEO]. *)

val viewport_args : backend -> string option -> string list
(** The Switch daemon's --viewport, when there is one; mGBA's frame is the
    picture. *)

val start :
  ?watch:watch ->
  ?flags:string list ->
  daemon:string ->
  backend:backend ->
  port:int ->
  wire_log:string ->
  out_file:string ->
  checkpoint:string ->
  unit ->
  (t, string) result
(** The daemon started and ready (its ports read from its output). The run
    folder always: the daemon keeps the run's notes there and, when recording,
    its frames (Watch-Page.md, Past runs). [flags] are the user's --record,
    --no-record and --keepawake, as given. *)

val stop : t -> unit
(** SIGTERM, then wait for it to exit. *)

val wait : t -> unit
(** Waits until the daemon exits, stopping it cleanly on SIGINT or SIGTERM. *)
