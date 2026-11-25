(** A on an A prompt until the game takes it, as PokemonLZA_AutoStoryWalks.cpp
    presses it, both for a walk into a talk and through a prompt. A held 160 ms;
    a read every 250 ms. A walk into a talk: released 240, the talk started once
    a scene is under way on two reads in a row; one second after an A with no
    scene, the prompt gone is nothing started (the walk goes on), the prompt
    still up takes A again, three in all ([talk_no_scene] after). Through a
    prompt (a door's "A Enter"): released 400, taken on one read of a fade or a
    text or choice box, three seconds between As (a late fade starts 1.8 s after
    the A), three in all, then logged and left. *)

type game_steps = {
  submit : Wire.command -> unit;
  read_screen : unit -> Screen.t;
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

val press_through : game_steps -> unit
(** Through a prompt, as PokemonLZA_AutoStoryWalks.cpp: A on the prompt until
    the game takes it; a prompt still up after three As is logged, not failed
    (the scene after it fails instead). *)

val steady : game_steps -> bool
(** The prompt still up 300 ms on: a first glimpse can be it fading in or the
    player still moving. *)
