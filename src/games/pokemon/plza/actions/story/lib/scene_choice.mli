(** A story scene's choice when it does not stop there: Up until the top row is
    highlighted, then A (logged); A when the rows do not read. Moved unchanged
    from {!Scene_machine}; ported from PokemonLZA_AutoStorySceneMachine.cpp. *)

val button : Steps.game_steps -> Look.t -> Wire.button
(** The press for this read of the choice. *)
