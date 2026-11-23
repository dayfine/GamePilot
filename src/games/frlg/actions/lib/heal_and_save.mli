(** The Pokémon Center nurse and the Start menu's SAVE, the story's [heal] and
    [save] (the fork's heal_at_center and save in PokemonFRLG_Navigation), each
    page and question waited on. *)

val nurse_front : Story.Pose.grid
(** Where the player talks to the nurse on any Center's ground floor (the map is
    left blank: a caller names the Center): tile (7, 4) facing north. *)

val center_map : string -> string
(** ["LavenderTown"] -> ["LavenderTown_PokemonCenter_1F"]. *)

val heal_at_nurse : log:(string -> unit) -> unit -> unit
(** Facing the nurse: A, the pages turned, YES, then the talk settle through the
    healing. Fails as [heal_no_question]. *)

val save_row : int
(** SAVE on the full Start menu: 4. *)

val overwrite_question_ms : int
(** How long the second question (overwrite the save there?) may take to come
    after the first YES: 3 s. *)

val save : log:(string -> unit) -> unit -> unit
(** START, SAVE, YES, YES again if the game asks to overwrite, then the talk
    settle once it has saved. Fails as [no_start_menu] or [save_no_question]. *)
