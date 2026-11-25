(** A on the A prompt a walk reached, until a talk starts: [a_at_prompt] with
    [WALK_TALK] and [talk_at_walk_prompt] of PokemonLZA_AutoStoryWalks.cpp
    ([plza/lean]). A held 160 ms, released 240; a read every 250 ms; the talk
    started once a scene is under way on two reads in a row. One second after an
    A with no scene: the prompt gone is nothing started (the walk goes on); the
    prompt still up takes A again, three in all ([talk_no_scene] after). *)

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Walk_screen.t;
  log : string -> unit;
  log_detail : string -> unit;
}
(** What the talk reads and does in the game (the walk's own steps). *)

val talk :
  game_steps ->
  string ->
  held_ms:int ->
  (unit, Engine_run.Failure.cause) result option
(** [talk steps walk ~held_ms]: [Some (Ok ())] once the talk started,
    [Some (Error _)] when the prompt stayed up, [None] when it went with nothing
    started. [held_ms] (of the last leg) is for the log. *)

val steady : game_steps -> bool
(** The prompt still up 300 ms on: a first glimpse can be it fading in or the
    player still moving. *)
