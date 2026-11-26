(** A game's menu screens as a graph: a screen type, one reader answering with
    candidate screens, and a pure edge function (design:
    [docs/design/Screen-Graph.md]).

    The library is game-agnostic: nothing here names a game, a menu, or a button
    meaning. {!path} searches over {!Transit} edges only so {!Acts} edges (such
    as claiming a gift or saving) are never walked through accidentally. *)

(** How long a screen must read after an edge's input before the hop counts. *)
type arrive =
  | Held of int  (** Must read steadily for this many milliseconds. *)
  | First_read  (** Counts on the first frame that reads the target. *)

(** Whether an edge only navigates or performs a side-effecting action. *)
type kind =
  | Transit  (** Pure navigation; used by {!path} and {!Screen_walk.go_to}. *)
  | Acts of string
      (** Named action (e.g. ["claim"], ["save"]); never walked through by
          {!path}, only invoked explicitly via {!Screen_walk.take}. *)

type 'screen edge = {
  input : Wire.command list;
      (** Input to send (normally one press, with its hold and cooldown). *)
  leads_to : 'screen;
      (** Expected destination screen, used for path planning and settling
          look-alike screens. *)
  arrive : arrive;  (** How long the destination must read after [input]. *)
  within_ms : int;  (** Timeout waiting for a known screen after [input]. *)
  kind : kind;  (** Whether this edge is {!Transit} or {!Acts}. *)
}
(** One directed transition between screens. *)

(** What the walker may do when a frame reads as no known screen. *)
type when_unread =
  | Fail  (** Fail immediately without pressing anything (the default). *)
  | Press of Wire.command list
      (** Send a declared safe recovery input (capped and logged by
          {!Screen_walk}). *)

type 'screen t = {
  name : string;  (** Graph name, used in diagnostics and {!check} errors. *)
  probes : Wire.probe_spec list;
      (** Probes required by [read] and [describe]. *)
  read : Wire.frame -> 'screen list;
      (** Every screen the frame could be, or [[]] when unread. *)
  edges : 'screen -> 'screen edge list;
      (** Outgoing edges from a screen (pure function). *)
  screens : 'screen list;
      (** Every valid screen of the graph, parameters expanded. *)
  home : 'screen;
      (** Recovery screen every other screen must reach by {!Transit} edges. *)
  when_unread : when_unread;  (** Policy when a frame reads as no screen. *)
  show : 'screen -> string;  (** Human-readable name of a screen. *)
  describe : Wire.frame -> string;
      (** Diagnostic summary of a frame for failure messages. *)
}
(** A declared screen graph. *)

val exactly : 'screen -> 'screen -> bool
(** [exactly target] is the predicate matching only [target]. *)

val path :
  'screen t -> from:'screen -> at:('screen -> bool) -> 'screen edge list option
(** Shortest path of {!Transit} edges from [from] to the nearest screen matching
    [at] (breadth-first search). Returns [Some []] when [at from] holds, or
    [None] when unreachable. *)

val find_act : 'screen t -> from:'screen -> string -> 'screen edge option
(** [find_act graph ~from name] finds the outgoing {!Acts} edge named [name]
    from [from]. *)

val check : 'screen t -> (unit, string) result
(** Validate a graph's structural invariants: [home] is in [screens], every
    edge's [leads_to] is in [screens], every screen reaches [home] by {!Transit}
    edges alone, and {!Acts} names are unique per source screen. *)
