(** A through text and tutorial cards: the fork's [press_a_through_lines]
    (PokemonLZA_AutoStoryScenes.cpp, [plza/lean]). The screen is read every 250
    ms; on text (TEXT_SHOWS) or a tutorial card, A (160 ms, released 240) and
    the next read straight after; the lines are passed once neither shows for
    [quiet_ms]. Up to [limit_ms] (and [limit_ms / 250 + 1] reads), or the HOME
    menu: timed out. *)

type passed = {
  text : bool;  (** text showed *)
  card : bool;  (** a tutorial card showed *)
  timed_out : bool;
}

val run : Story_steps.game_steps -> quiet_ms:int -> limit_ms:int -> passed
