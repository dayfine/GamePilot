(** The checkpoint engine's modules over one game family's terms: its plans
    (read and printed), its handlers, the runner, and what a run keeps and
    loops. A family applies it once (Pokémon: [Pokemon_checkpoints]) and its
    games use that application's modules, whose types carry the family's poses,
    kinds and promises ([docs/design/Engine-Boundary.md], section 2). *)

(** The engine's modules over [T]. *)
module Make (T : Engine_terms.GAME_TERMS) : sig
  (** {!Engine_plan.Plan.Make}: the plan's types. *)
  module Plan : module type of struct
    include Engine_plan.Plan.Make (T)
  end

  (** {!Engine_plan.Plan_decode.Make}: reads a plan file. *)
  module Plan_decode : module type of struct
    include Engine_plan.Plan_decode.Make (T)
  end

  (** {!Engine_plan.Plan_text.Make}: a plan as text. *)
  module Plan_text : module type of struct
    include Engine_plan.Plan_text.Make (T)
  end

  (** {!Engine_run.Failure.Make}: why a run stopped. *)
  module Failure : module type of struct
    include Engine_run.Failure.Make (T)
  end

  (** {!Engine_run.Game.Make}: the game's handlers. *)
  module Game : module type of struct
    include Engine_run.Game.Make (T)
  end

  (** {!Engine_run.Runner.Make}: runs a checkpoint's events. *)
  module Runner : module type of struct
    include Engine_run.Runner.Make (T)
  end

  module Event_states = Engine_run.Event_states
  (** {!Engine_run.Event_states}: where a run keeps its states. *)

  (** {!Engine_run.Repeat_until.Make}: a looped checkpoint. *)
  module Repeat_until : module type of struct
    include Engine_run.Repeat_until.Make (T)
  end
end
