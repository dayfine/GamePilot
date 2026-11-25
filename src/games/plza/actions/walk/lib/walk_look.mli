(** What a walk reads on one look at the screen: the screen events and readings
    the C++'s walk tests ([ScreenObservation], [PlzaConsoleBackend::observe]),
    and its screen predicates ([FADE_SHOWS], [OVERWORLD_FREE],
    [PokemonLZA_AutoStoryScreenPredicates.h]; [not_free_control],
    [PokemonLZA_AutoStoryWalks.cpp]). PLZA's readers fill it; until they come,
    tests do. *)

type t = {
  at_ms : float;  (** When the frame was read, on the daemon's clock. *)
  home_menu : bool;  (** The Switch HOME menu, not the game. *)
  screen_still : bool;  (** The frame is the same as the last look's. *)
  fade_black : bool;
  fade_white : bool;
  dialog_box : bool;  (** A text box, or a choice box. *)
  advance_arrow : bool;  (** The advance chevron, with a box or without. *)
  player_can_move : bool;  (** The party bar. *)
  controls_hint : bool;  (** The tutorial's controls hint, ["(L) Move"]. *)
}
(** One look. *)

val nothing : at_ms:float -> t
(** A look with nothing set. *)

val fade_shows : t -> bool
(** A black or white fade. *)

val overworld_free : t -> bool
(** The party bar or the controls hint, with no dialog, fade or advance chevron.
*)

val not_free_control : t -> string option
(** What keeps control from being free (["text waiting for A"], ["a text box"],
    ["a fade"]); [None] when nothing does. *)

val shows : Plza_terms.Walk_args.end_event -> t -> bool
(** Whether the look shows a walk's end event. *)

val events : t -> string
(** The events and readings set, as ["fade_white, screen_still"], or ["none"]:
    the log's view of a look. The C++ prints its event set and, for an end, its
    scene machine's description; this prints the fields alone. *)
