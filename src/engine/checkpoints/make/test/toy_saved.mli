(** What a toy run keeps beside an event's state: the gold at the checkpoint's
    start ([start_gold]) and the zone the player was reckoned to stand in
    ([at]), through the engine's {!Engine_saved.Kept}. *)

module Start : Engine_saved.Kept.FIELDS with type t = int option
(** The gold at the start, as [start_gold]. *)

include
  Engine_saved.Event_states.SAVED
    with type t = (int option, Toy_rules.Pose.t) Engine_saved.Kept.kept
