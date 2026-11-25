(** Talking and scenes on FireRed: A to the person or thing the player faces,
    then the talk settle ({!Scene_looks.settle}); a scene is the settle alone.
    The fork's AutoStory [talk] and [scene] events. *)

val talk :
  log:(string -> unit) ->
  unit ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** Ends at a quiet overworld, or at a battle (a trainer's, which the plan's
    next event fights); fails as [not_settled]. *)

val pick_up :
  log:(string -> unit) ->
  unit ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** A to the faced item ball or hidden item: its text box must show within
    {!item_text_ms}, or it fails as [nothing_picked_up] (a walk that ended a
    tile short faces nothing: A shows no box, and the plan went on as if picked
    up; console B, tt-01, 2026-11-24). Then the talk settle. *)

val item_text_ms : int

val scene :
  log:(string -> unit) ->
  unit ->
  (unit, Pokemon_checkpoints.Failure.cause) result

val answer :
  log:(string -> unit) ->
  yes:bool ->
  unit ->
  (unit, Pokemon_checkpoints.Failure.cause) result
(** The plan's [answer] event: A to the person the player faces, and the Yes/No
    question their text comes to answered. YES as {!Menu_input.answer_yes}
    answers it, then the talk settle through whatever the answer starts (Bill's
    YES in the Cinnabar Center runs on to One Island), ending at a quiet
    overworld or at a battle the answer starts, as {!talk} does (the Three
    Island Biker's "You wanna make something of it or what?": YES, and the
    Bikers' battles, which the plan's next event fights); fails as [no_question]
    when no question shows. In a scene the speaker's text is up already, and the
    A turns its page. NO is the talk itself: its settle presses B, and B answers
    NO. The fork's [answer] follows a [talk] that stops at the first message
    (talk_until_message); here a [talk] settles through the question, so an
    [answer] starts the talk itself and the plan has no [talk] before it. *)
