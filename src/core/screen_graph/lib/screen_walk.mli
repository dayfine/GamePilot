(** Read-driven screen navigation over a {!Graph.t} (design:
    [docs/design/Screen-Graph.md]).

    {!go_to} reads where the game is, plans a shortest {!Graph.Transit} path,
    sends the first hop's input, and reads again until the target predicate
    holds. {!take} verifies the source screen has held, sends a named
    {!Graph.Acts} edge, and returns the screen that held afterward. *)

type 'screen game_steps = {
  read_screen : hold_ms:int -> within_ms:int -> 'screen list;
      (** Wait up to [within_ms] for a non-empty candidate screen list to hold
          for [hold_ms]; returns [[]] when none held. *)
  describe_last : unit -> string;
      (** Diagnostic description of the latest frame, for failure messages. *)
  send : Wire.command list -> unit;  (** Submit an edge's input commands. *)
  log : string -> unit;  (** Log a status line. *)
}
(** What the walker reads and sends in the game. *)

(** Why {!go_to} or {!take} failed. *)
type 'screen failure =
  | Unread of { last : string }
      (** No unambiguous known screen held within the timeout. *)
  | No_path of { from : 'screen }
      (** No {!Graph.Transit} path from [from] to the target, or no matching
          {!Graph.Acts} edge on [from]. *)
  | Out_of_hops of { on : 'screen }
      (** Exhausted the hop budget while still on [on]. *)
  | Not_on of { wanted : 'screen; last : string }
      (** {!take}'s source screen [wanted] did not hold before acting. *)

val default_max_hops : int
(** Default hop budget for {!go_to} (40). *)

val default_hold_ms : int
(** Default screen-hold duration before reading (1000 ms). *)

val default_within_ms : int
(** Default wait timeout for the initial read (3000 ms). *)

val max_unread_presses : int
(** Maximum consecutive {!Graph.Press} recovery inputs on unread screens (3). *)

val failure_to_string : 'screen Graph.t -> 'screen failure -> string
(** Format a failure with screen names from the graph. *)

val go_to :
  ?max_hops:int ->
  ?hold_ms:int ->
  ?within_ms:int ->
  'screen Graph.t ->
  'screen game_steps ->
  at:('screen -> bool) ->
  ('screen, 'screen failure) result
(** Walk {!Graph.Transit} edges until a screen satisfying [at] holds, returning
    the reached screen. *)

val take :
  ?hold_ms:int ->
  ?within_ms:int ->
  'screen Graph.t ->
  'screen game_steps ->
  from:'screen ->
  string ->
  ('screen, 'screen failure) result
(** Verify [from] has held unambiguously, send its named {!Graph.Acts} edge, and
    return the known screen that holds afterward. *)
