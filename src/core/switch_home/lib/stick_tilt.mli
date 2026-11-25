(** The left stick tilted toward an angle, as the daemon presses it: the fork's
    left-stick press ([NintendoSwitch_Commands_PushButtons.h]) with its position
    from an angle, and a run as a button held with the stick. Moved out of
    PLZA's [PokemonLZA_AutoStoryConsoleBackend.cpp] port, since any game that
    moves on the stick turns angles into tilts the same way; how much faster a
    game runs is the game's to say. *)

val toward : degrees:float -> (Wire.stick, string) result
(** The stick toward [degrees] clockwise from straight on (up): [(sin, cos)], +x
    right and +y up. *)

type run = {
  button : Wire.button;  (** The button held with the stick to run (B). *)
  speedup : float;
      (** How many times walking's distance running covers in the same time: a
          run is held for its walk time over this. *)
}
(** How a game runs. *)

val tilt :
  ?run:run ->
  degrees:float ->
  duration_ms:int ->
  release_ms:int ->
  unit ->
  (Wire.command, string) result
(** The stick held toward [degrees] for [duration_ms], then centred for
    [release_ms]. With [run], its button is held with it, for
    [duration_ms /. run.speedup] (truncated). *)
