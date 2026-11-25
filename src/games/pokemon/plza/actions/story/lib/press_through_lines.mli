(** A through text and tutorial cards: ported from
    PokemonLZA_AutoStoryScenes.cpp. The screen is read every 250 ms; on text
    ({!Look.text_shows}) or a tutorial card, A (160 ms, released 240) and the
    next read straight after; the lines are passed once neither shows for
    [quiet_ms]. Up to [limit_ms] (and [limit_ms / 250 + 1] reads), or the HOME
    menu: timed out. *)

type passed = {
  text : bool;  (** text showed *)
  card : bool;  (** a tutorial card showed *)
  timed_out : bool;  (** the limit or the HOME menu came first *)
}
(** What the lines passed showed, and how they ended. *)

val run : Steps.game_steps -> quiet_ms:int -> limit_ms:int -> passed
(** A through the lines until quiet, as above. *)
