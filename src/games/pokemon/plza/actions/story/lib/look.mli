(** One read of a PLZA story screen, and what the story actions judge from it:
    the fork's screen observation as PokemonLZA_AutoStoryConsoleBackend.cpp
    fills it, and the matches of PokemonLZA_AutoStoryScreenPredicates.h. Plain
    values: the live screen fills it from the readers, tests by hand.

    Not read: the "mission complete" card, which has no reader yet; it reads as
    not shown. *)

(** A move's effectiveness symbol under ZL, weakest first. *)
type effectiveness =
  | No_effect  (** The crossed-out symbol. *)
  | Not_very_effective  (** One down arrow. *)
  | Effective  (** One up arrow. *)
  | Super_effective  (** Two up arrows. *)

type map_point = { x : float; y : float }
(** A point on the full map, which is the frame scaled to 800 x 450, as the
    fork's map points. *)

type t = {
  at_ms : float;  (** When the frame was read, on the daemon's clock. *)
  frame_read : bool;
      (** A frame came: [false] for {!no_frame}, where every other field reads
          nothing. *)
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
  interact_prompt : bool;  (** An A prompt (["(A) Talk"]) with no text box. *)
  party_bar : bool;  (** The overworld party bar with no text box. *)
  map_pin : map_point option;
      (** The player's pin on the full map, when it is open
          ({!Plza_readers.Map_pin}). *)
  minimap_arrow : float option;
      (** The bearing the minimap's arrow points, degrees clockwise from up
          ({!Plza_readers.Minimap_arrow}), as the fork reads the facing. *)
  run_prompt : bool;
      (** A wild battle's Run prompt (its minus button), as the fork's
          run-from-battle detector reads it. *)
  main_menu : bool;
      (** The game's main menu (X), as the fork's detector reads it. *)
  alert_eye : bool;
      (** The eye on a wild Pokemon's alert bar, as the fork's detector reads
          it. *)
  minimap : string option;
      (** The recorded minimap the top-left one matches
          ({!Plza_readers.Minimap}), as the fork's start signature reads it. *)
  battle : bool;  (** The battle HUD. *)
  lead_hp : float option;
      (** The lead's HP bar under its level badge, as the share of the bar's box
          in the fill colours ({!Plza_readers.Battle_hud.lead_hp}): 0.89 for any
          HP over about 70%, 0.04 at 1 HP of 19; [None] without the badge. *)
  story_dialog : bool;
      (** A dialogue box as the fork's story dialogue detector reads it by
          default (the white box with its arrow, blue or teal): the end of a
          story battle. *)
  moves : effectiveness option list;
      (** The four moves' symbols (top, left, right, bottom) while ZL is held;
          empty when not read. *)
  confirm_row : int option;
      (** On the new game's Confirm Choices: the highlighted row. *)
}
(** What one read of the screen shows. *)

val empty : at_ms:float -> t
(** A read with nothing on it. *)

val no_frame : at_ms:float -> t
(** No frame came: {!empty} with [frame_read] false. *)

val fade_shows : t -> bool
(** A black or white fade. *)

val text_shows : t -> bool
(** A text box, or the advance chevron without one. *)

val text_waiting_for_a : t -> bool
(** A text box with the advance chevron. *)

val control_shows : t -> bool
(** The party bar, the controls hint or an A prompt, with no text box. *)

val hud_shows : t -> bool
(** The HUD, as the scene machine checks it: the party bar, the controls hint or
    an A prompt. *)

val scene_busy : t -> bool
(** Text, a fade or a card (no "mission complete" reader). *)

val overworld_free : t -> bool
(** The party bar or the controls hint, with no text box, fade or chevron. *)

val platform_hint : t -> bool
(** The controls hint, no text box and no autosave badge. *)

val card_shows : t -> bool
(** A tutorial card. *)

val scene_under_way : t -> bool
(** A scene under way, as the scene machine checks it: text, a choice, a battle
    or a card; else, with no sign of control, a fade or a moving screen. *)

val moves_shown : t -> bool
(** A move effectiveness symbol shows: ZL locked on. *)

val describe : t -> string
(** What shows, as the fork's log lists it ("black fade, text box, still,
    controls hint"), or ["nothing"]. *)

val to_walk_screen : t -> Plza_walk.Walk_screen.t
(** The read as the walk takes it. *)

val wild_battle_on : t -> bool
(** A wild battle on, as the catches check it: the Run prompt, or the alert eye
    while a wild Pokemon attacks before the partner is out. *)
