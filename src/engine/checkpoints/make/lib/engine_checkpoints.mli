(** The checkpoint engine over one game family: its plans (read and printed),
    its handlers, the runner, and what a run keeps and loops. A family applies
    it once (Pokémon: [Pokemon_checkpoints]) and its games use that
    application's modules, whose types carry the family's poses, kinds and
    promises ([docs/design/Engine-Boundary.md], section 2).

    The family gives four modules. [T] is its rules, which the runner, the
    failures and the checks use alone; the other three are the formats, each
    bound to [T] and each used by one edge only: [C] by {!Make.Plan_decode}, [X]
    by {!Make.Plan_text} and the printed log and failures, [S] by
    {!Make.Event_states}. [T] comes first and on its own so that every module
    here is applied to the same path [T]: the plan's types are then the same for
    the decoder, the text and the runner. *)

(** The engine's modules over [T]. *)
module Make
    (T : Engine_rules.GAME_RULES)
    (C : Engine_plan_codec.Plan_codec.PLAN_CODEC with module T = T)
    (X : Engine_text.Rules_text.TEXT with module T = T)
    (S : Engine_saved.Event_states.SAVED) : sig
  (** {!Engine_plan.Plan.Make}: the plan's types, a game action's args the
      plan's JSON ({!Engine_plan_codec.Raw_json}). *)
  module Plan : module type of struct
    include Engine_plan.Plan.Make (T) (Engine_plan_codec.Raw_json)
  end

  (** {!Engine_plan_codec.Plan_decode.Make}: reads a plan file. *)
  module Plan_decode : module type of struct
    include Engine_plan_codec.Plan_decode.Make (T) (C)
  end

  (** {!Engine_text.Plan_text.Make}: a plan as text. *)
  module Plan_text : module type of struct
    include Engine_text.Plan_text.Make (T) (X)
  end

  (** {!Engine_run.Failure.Make}: why a run stopped, and
      {!Engine_text.Failure_text.Make}: that as text. *)
  module Failure : sig
    include module type of struct
      include Engine_run.Failure.Make (T)
    end

    include module type of struct
      include Engine_text.Failure_text.Make (T) (X)
    end
  end

  (** {!Engine_run.Game.Make}: the game's handlers. *)
  module Game : module type of struct
    include Engine_run.Game.Make (T) (Engine_plan_codec.Raw_json)
  end

  (** {!Engine_run.Runner.Make}, its lines printed to the game's log. *)
  module Runner : sig
    val run :
      ?end_at:T.Pose.t ->
      ?end_state:
        T.Postconditions.t * (T.Postconditions.t -> T.Postconditions.reads) ->
      ?on_event:(int -> string Engine_run.Event_progress.t -> unit) ->
      ?events:Engine_run.Event_range.t ->
      Game.t ->
      Plan.checkpoint ->
      (unit, Failure.t) result
    (** {!Engine_run.Runner.Make.run}, each line it says printed
        ({!Engine_text.Run_text.Make.line}) to [game.log], and a failed event's
        reason given to [on_event] as logged. *)
  end

  (** {!Engine_watch.Plan_watch.Make}: a plan's run on the watch page, its
      events as the steps. *)
  module Plan_watch : module type of struct
    include Engine_watch.Plan_watch.Make (T) (Engine_plan_codec.Raw_json)
  end

  (** {!Engine_saved.Event_states}: where a run keeps its states, and what it
      keeps beside them through [S]. *)
  module Event_states : sig
    include module type of struct
      include Engine_saved.Event_states
    end

    include module type of struct
      include Engine_saved.Event_states.Make (S)
    end
  end

  (** {!Engine_run.Repeat_until.Make}: a looped checkpoint, its lines printed to
      the game's log. *)
  module Repeat_until : sig
    include module type of struct
      include Engine_run.Repeat_until.Make (T) (Engine_plan_codec.Raw_json)
    end

    val run :
      limits ->
      goal:(unit -> (bool, Failure.cause) result) ->
      Game.t ->
      Plan.checkpoint ->
      (int, stop) result
    (** {!Engine_run.Repeat_until.Make.run}, printed to [game.log]. *)

    val stop_to_string : stop -> string
    (** {!Engine_text.Run_text.Make.stop}. *)
  end
end
