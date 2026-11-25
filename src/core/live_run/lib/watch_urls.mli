(** Where a run's watch page and the hub are, as the runner prints them
    (docs/design/Watch-Page.md): on this machine, and, when the page listens
    beyond it, from another device on the LAN (with Stop's token in the run's
    URL). *)

val hub_port : int
(** The hub's port, 47901. *)

val local : string
(** ["127.0.0.1"]. *)

val default_listen : unit -> string
(** --listen's default: $GAMEPILOT_WATCH_LISTEN (the runner's env file may set
    it to 0.0.0.0), else this machine only. *)

val new_token : unit -> string
(** Stop's token for a series: 32 random hex digits. *)

val url : ?token:string -> string -> int -> string
(** The page at a host and port, with Stop's token when given. *)

val print : listen:string -> token:string -> port:int -> unit
(** The page's address for this machine and, listening beyond it, for others. *)
