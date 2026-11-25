(** What a PLZA run keeps beside an event's state, and its JSON, derived
    ([[@@deriving yojson]]). PLZA has no emulator, so no event states are
    written yet; the engine still needs the format. *)

type t = { at : Plza_terms.Pose.zone option }
(** Where the player was reckoned to stand. PLZA's promises read nothing at a
    checkpoint's start. *)

include Engine_saved.Event_states.SAVED with type t := t
