(** What {!Battle_steps}'s [next_event] does at each look: the one table from
    the screen to an answer. Pure: a state is a value, and each look returns the
    next one.

    Battle text is pressed through with B when its red arrow says the page is
    done, at most once per {!arrow_press_gap_ms} (a B before the arrow would
    skip nothing, and one that lands on a double battle's second action menu
    would take back the first battler's command). Text with no arrow is left to
    run on; only if it stays {!stuck_text_ms} does it get a B, with an HP box up
    or without one (a trainer's lines before and after the battle: Lea & Jed's
    defeat text sat with no arrow until mg-05 testing 1 timed out). Only once a
    level-up box has shown in this battle can that screen be an evolution, and
    then it never gets a B: any B cancels an evolution. The fork's Mail Glitch
    battle loop presses B on any battle text held 1.5 s (step_non_menu_
    battle_frame(), Programs/MailGlitch/PokemonFRLG_MailGlitchBattle.cpp); its
    AutoStory loop holds for an evolution only after a turn that attacked. B
    never answers YES. The battle is over once no battle screen has shown for
    {!over_after_ms}, after one did. *)

type state

val start : at_ms:float -> state
(** Before the first look; nothing pressed yet, no battle seen. *)

(** The answer to a look. *)
type step =
  | Report of Battle.event  (** [next_event] returns this *)
  | Press of Wire.button  (** then look again *)
  | Look  (** nothing to do yet: look again *)

val next : state -> Battle_look.facts -> at_ms:float -> state * step
(** The state after a look taken at [at_ms] (daemon clock) and its answer. *)

val arrow_press_gap_ms : float
(** 0.5 s: a tap takes 0.4 s (140 ms held, 260 ms after), and the arrow is gone
    from the next frame, so a second B within this would hit the next page
    before its arrow. *)

val press_gap_ms : float
(** 1.5 s, the fork's STUCK wait: the level-up box's A, a stray move menu's or
    bag's B, once the screen has held this long since the last press. *)

val stuck_text_ms : float
(** 6 s of battle text with no arrow, since the last press: something waits that
    no reader knows, so B. Not measured: longer than the move animations seen
    under their text on mGBA (about 3 s). *)

val over_after_ms : float
(** 3 s with no battle screen: the fade out of a battle is shorter, a wild
    battle's text after RUN is a battle screen. *)
