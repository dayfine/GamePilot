(** Initiating Surf from a shore tile facing water (the ["surf"] game action).

    From the shore facing water, presses A to trigger the Surf prompt, answers
    YES to surf onto the water tile, and waits for the overworld to settle. *)

val surf : log:(string -> unit) -> unit
(** Presses A facing water, answers YES on the Surf prompt, and settles back to
    the overworld on water. Raises {!Menu_input.Action_failed} with
    ["surf_no_prompt"] if the Surf Yes/No dialog does not appear. *)
