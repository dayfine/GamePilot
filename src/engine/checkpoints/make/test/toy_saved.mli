(** What a toy run keeps beside an event's state, and its JSON. *)

type t = { start : int option; at : Toy_terms.Pose.t option }
(** The gold at the checkpoint's start, and where the player was reckoned to
    stand. *)

include Engine_saved.Event_states.SAVED with type t := t
