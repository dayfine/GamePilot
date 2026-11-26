(** The Pokémon Center nurse and the Start menu's SAVE, the story's [heal] and
    [save] (the fork's heal_at_pokecenter in PokemonFRLG_Navigation, and
    {!Game_save}). The heal mashes as the fork's does. *)

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

val save : log:(string -> unit) -> unit -> unit
(** The in-game save, {!Game_save.save} (the fork's [save_game()]). *)
