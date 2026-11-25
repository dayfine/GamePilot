(** A checkpoint plan ([gamepilot-checkpoint/1], owned by GamePilot; once
    PokemonSimulation's [pokesim-authored-checkpoint/1]): the stretch of story
    between two saves, as a list of events, over a game's rules
    ({!Engine_rules.GAME_RULES}). Types only, and pure: [Engine_plan_format]
    reads them from a plan file.

    The engine's story actions ([talk], [answer], [scene], [save]) and
    [game_action] are typed here; every other kind is one of the game's actions
    ([Game]). A [game_action]'s args stay as written ({!RAW}): the game that
    names the action reads them. *)

(** What the plan keeps unread: a game action's args, the [execution] and the
    [metadata]. The engine applies the plan to [Engine_plan_format.Raw_json],
    the plan's own JSON. *)
module type RAW = sig
  type t
end

(** The plan's types over the game's rules. *)
module Make (T : Engine_rules.GAME_RULES) (Raw : RAW) : sig
  (** What an event does, with its args. *)
  type kind =
    | Talk
    | Answer of bool  (** Answer a yes/no prompt: [true] for yes. *)
    | Scene  (** Clear dialog and cutscenes back to free control. *)
    | Save
    | Named_action of Raw.t
        (** A game action named by the event's {!way} (the plan's [action]),
            with its args. *)
    | Game of T.Action.t  (** One of the game's actions, with its args. *)

  type event = {
    id : string;  (** Unique within the checkpoint. *)
    kind : kind;
    way : string option;
        (** The plan's [action] (the JSON key stays ["action"]): which of its
            kind's ways the event takes (["run"] for a route), or the game
            action's name; [None] for the kind's default. Always set for a
            {!Named_action}. *)
    why : string;  (** What the event is for, in the plan author's words. *)
    skip_if : string list;
        (** Flags (named by the game) under which the event is skipped. *)
    declared_after : T.Pose.t option;
        (** Where the event leaves the player, as the plan declares it. *)
    once_per_save : bool;
        (** The event spends something the save keeps (money, a TM): the game
            runs it once per save. *)
  }
  (** One step of the story. *)

  type checkpoint = {
    checkpoint_id : string;
    title : string;
    start : T.Pose.t option;
    events : event list;
  }
  (** The plan's [checkpoint]: where it starts and its events in order. *)

  type repeat = {
    until : T.Postconditions.t;
        (** The goal, read after each passing round: the rounds end once it
            holds. *)
    max_rounds : int;  (** Rounds to run before giving up; at least 1. *)
  }
  (** The metadata's [repeat]: the checkpoint is a round that runs again (each
      pass saved like any checkpoint's) until [until] holds. It starts and ends
      at the same place, its save point: 05-grind-mr-mime's grind round, from
      the Indigo Plateau nurse back to her. *)

  type t = {
    game : string;  (** The plan's [game], e.g. ["frlg"]. *)
    checkpoint : checkpoint;
    execution : Raw.t;
        (** How the game runs the checkpoint (save menu, supplies, ...): its
            fields are each game's own. *)
    metadata : Raw.t option;
        (** The plan's phase, verification and postconditions, kept as written.
        *)
    postconditions : T.Postconditions.t option;
        (** The metadata's postconditions, read; [None] when it states none. *)
    retries : int;
        (** The metadata's ["retries"] (default 0): how many more attempts a run
            of the checkpoint makes from its start after a failed one
            ([Engine_run.Checkpoint_trials.attempts]). *)
    repeat : repeat option;  (** The metadata's [repeat], if any. *)
  }
  (** A plan file, read. *)
end
