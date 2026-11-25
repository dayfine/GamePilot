(** Talking and scenes on FireRed: A to the person or thing the player faces,
    then the talk settle ({!Scene_looks.settle}); a scene is the settle alone.
    The fork's AutoStory [talk] and [scene] events. *)

val talk :
  log:(string -> unit) -> unit -> (unit, Checkpoints_run.Failure.cause) result
(** Ends at a quiet overworld, or at a battle (a trainer's, which the plan's
    next event fights); fails as [not_settled]. *)

val pick_up :
  log:(string -> unit) -> unit -> (unit, Checkpoints_run.Failure.cause) result
(** A to the faced item ball or hidden item: its text box must show within
    {!item_text_ms}, or it fails as [nothing_picked_up] (a walk that ended a
    tile short faces nothing: A shows no box, and the plan went on as if picked
    up; console B, tt-01, 2026-11-24). Then the talk settle. *)

val item_text_ms : int

val scene :
  log:(string -> unit) -> unit -> (unit, Checkpoints_run.Failure.cause) result
