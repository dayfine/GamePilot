(** The Pokémon Center nurse and the Start menu's SAVE, the story's [heal] and
    [save] (the fork's heal_at_pokecenter and save in PokemonFRLG_Navigation).
    The save waits on each page and question; the heal mashes as the fork's
    does. *)

val nurse_front : Story.Pose.grid
(** Where the player talks to the nurse on any Center's ground floor (the map is
    left blank: a caller names the Center): tile (7, 4) facing north. *)

val center_map : string -> string
(** ["LavenderTown"] -> ["LavenderTown_PokemonCenter_1F"]. *)

val heal_at_nurse : log:(string -> unit) -> unit -> unit
(** Facing the nurse, the fork's heal_at_pokecenter (PokemonFRLG_Navigation,
    [frlg/lean]): A until the white text box shows ({!dialog_presses}, the
    fork's 10 s), A mashed {!mash_a_ms} (its pages, YES, the healing), B mashed
    {!mash_b_ms} (the last pages, or a talk the mash started again), then the
    talk settle. Unlike the fork, no walk up first: the route ends facing her.
    Her question is not waited on: her Yes/No box is not where
    {!Frlg_readers.Dialog.yes_no_cursor} looks (mGBA, Lavender Center, mg-03
    testing run 1), and YES is its default. Fails as [heal_no_dialog]. *)

val dialog_press_ms : int
(** After each A to the nurse: 340 ms, 500 ms a press. *)

val dialog_presses : int
(** 20: the fork's 10 s. *)

val mash_a_ms : int
(** 8 s, the fork's. *)

val mash_b_ms : int
(** 5 s, the fork's. *)

val save_row : int
(** SAVE on the full Start menu: 4. *)

val overwrite_question_ms : int
(** How long the second question (overwrite the save there?) may take to come
    after the first YES: 3 s. *)

val save : log:(string -> unit) -> unit -> unit
(** START, SAVE, YES, YES again if the game asks to overwrite, then the talk
    settle once it has saved. Fails as [no_start_menu] or [save_no_question]. *)
