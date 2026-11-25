(** One read of a PLZA story screen, and what the story actions judge from it:
    the fork's [ScreenObservation] as PokemonLZA_AutoStoryConsoleBackend.cpp
    fills it, and the matches of PokemonLZA_AutoStoryScreenPredicates.h
    ([plza/lean]). Plain values: the live screen fills it from the readers,
    tests by hand.

    Not read: the "mission complete" card, which has no reader yet; it reads as
    not shown. *)

(** A move's effectiveness symbol under ZL, weakest first (the fork's
    [MoveEffectivenessSymbol]). *)
type effectiveness =
  | No_effect
  | Not_very_effective
  | Effective
  | Super_effective

type t = {
  at_ms : float;  (** When the frame was read, on the daemon's clock. *)
  home_menu : bool;  (** The Switch HOME menu, not the game. *)
  screen_still : bool;  (** The frame is the same as the last read's. *)
  fade_black : bool;
  fade_white : bool;
  dialog_box : bool;  (** A text box, or a choice box. *)
  choice_box : bool;
  choice_rows : (int * int) option;
      (** With a choice box: the highlighted row (0 the top) and the rows. *)
  advance_arrow : bool;
  controls_hint : bool;
  autosave : bool;
  tutorial_card : bool;
  interact_prompt : bool;
      (** An A prompt (["(A) Talk"]) with no text box: [INTERACT_PROMPT]. *)
  party_bar : bool;
      (** The overworld party bar with no text box: [PLAYER_CAN_MOVE]. *)
  battle : bool;  (** The battle HUD: [BATTLE_STARTED]. *)
  story_dialog : bool;
      (** A dialogue box as [StoryDialogDetector] reads it by default (the white
          box with its arrow, blue or teal): the end of a story battle. *)
  moves : effectiveness option list;
      (** The four moves' symbols (top, left, right, bottom) while ZL is held;
          empty when not read. *)
  confirm_row : int option;
      (** On the new game's Confirm Choices: the highlighted row. *)
}

val empty : at_ms:float -> t
(** A read with nothing on it. *)

val fade_shows : t -> bool
(** FADE_SHOWS: a black or white fade. *)

val text_shows : t -> bool
(** TEXT_SHOWS: a text box, or the advance chevron without one. *)

val text_waiting_for_a : t -> bool
(** TEXT_WAITING_FOR_A: a text box with the advance chevron. *)

val control_shows : t -> bool
(** CONTROL_SHOWS: the party bar, the controls hint or an A prompt, with no text
    box. *)

val hud_shows : t -> bool
(** The scene machine's [hud_shows]: the party bar, the controls hint or an A
    prompt. *)

val scene_busy : t -> bool
(** SCENE_BUSY: text, a fade or a card (no "mission complete" reader). *)

val overworld_free : t -> bool
(** OVERWORLD_FREE: the party bar or the controls hint, with no text box, fade
    or chevron. *)

val platform_hint : t -> bool
(** PLATFORM_HINT: the controls hint, no text box and no autosave badge. *)

val card_shows : t -> bool
(** CARD_SHOWS: a tutorial card. *)

val scene_under_way : t -> bool
(** The scene machine's [scene_under_way]: text, a choice, a battle or a card;
    else, with no sign of control, a fade or a moving screen. *)

val moves_shown : t -> bool
(** A move effectiveness symbol shows: ZL locked on. *)

val describe : t -> string
(** What shows, as the fork's [describe_look] lists it ("black fade, text box,
    still, controls hint"), or ["nothing"]. *)

val to_walk_screen : t -> Plza_walk.Walk_screen.t
(** The read as the walk takes it. *)
