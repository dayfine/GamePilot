(** What a walk reads on the screen, and what it judges from it: a fade, free
    control, what keeps the player busy, a walk's end event. Ported from
    [PokemonLZA_AutoStoryScreenPredicates.h], [PokemonLZA_AutoStoryWalks.cpp]
    and the screen reads of [PokemonLZA_AutoStoryConsoleBackend.cpp] (fork
    #754). PLZA's readers fill it; until they come, tests do. *)

type t = {
  at_ms : float;  (** When the frame was read, on the daemon's clock. *)
  home_menu : bool;  (** The Switch HOME menu, not the game. *)
  screen_still : bool;  (** The frame is the same as the last read's. *)
  fade_black : bool;
  fade_white : bool;
  dialog_box : bool;  (** A text box, or a choice box. *)
  advance_arrow : bool;  (** The advance chevron, with a box or without. *)
  player_can_move : bool;  (** The party bar. *)
  controls_hint : bool;  (** The tutorial's controls hint, ["(L) Move"]. *)
}
(** One screen read. *)

val empty : at_ms:float -> t
(** A read with nothing on it. *)

val fade_shows : t -> bool
(** A black or white fade. *)

val player_free : t -> bool
(** The player has free control: the party bar or the controls hint, with no
    dialog, fade or advance chevron. *)

val busy_with : t -> string option
(** What keeps the player busy (["text waiting for A"], ["a text box"],
    ["a fade"]); [None] when nothing does. *)

val shows : Plza_rules.Walk_args.end_event -> t -> bool
(** Whether the screen shows a walk's end event. *)

val describe : t -> string
(** What is on the screen, as ["fade_white, screen_still"], or ["none"]: the
    log's view of a read. The C++ log names its screen events and, for an end,
    describes the scene; this prints the fields alone. *)
