(** Talking and scenes on FireRed: A to the person or thing the player faces,
    then the talk settle ({!Scene_looks.settle}); a scene is the settle alone.
    The fork's AutoStory [talk] and [scene] events. *)

val talk : log:(string -> unit) -> unit -> (unit, Story.Failure.cause) result
(** Ends at a quiet overworld, or at a battle (a trainer's, which the plan's
    next event fights); fails as [not_settled]. *)

val scene : log:(string -> unit) -> unit -> (unit, Story.Failure.cause) result
