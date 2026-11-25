(** What a toy run keeps beside an event's state: the gold at the checkpoint's
    start ([start_gold]) and the zone the player was reckoned to stand in
    ([at]), through the engine's {!Engine_event_snapshot.Kept}. *)

module Start : Engine_event_snapshot.Kept.FIELDS with type t = int option
(** The gold at the start, as [start_gold]. *)

include
  Engine_event_snapshot.Event_snapshot.SNAPSHOT
    with type t = (int option, Toy_rules.Pose.t) Engine_event_snapshot.Kept.kept
