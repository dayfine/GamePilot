(** Reader: what 01.01's story screen shows, every PLZA reading of one frame, as
    PokemonLZA_AutoStoryScreenEvents.cpp and
    PokemonLZA_AutoStoryConsoleBackend.cpp combine them. A black or white fade
    (the middle 80% of the frame, {!Screen_state.Fade}) hides the dialogue and
    choice boxes; the dialogue box is read as {!Dialog_box.Box_only}; a choice
    box shows when its arrow does, or when a dialogue box shows and its rows
    read, and a choice box counts as a dialogue box. The autosave badge,
    controls hint, advance chevron and tutorial card read through a fade.

    Not read here: the Switch HOME menu ({!Switch_home.Home_screen}); whether
    the screen is still (the fork compares the frame with the one before, which
    no probe does yet); whether the player can move (the fork's PLZA screen
    never says so; the controls hint stands for it). *)

type t = {
  fade : Screen_state.Fade.t;
  dialog_box : bool;
  choice_box : bool;
  advance_arrow : bool;
  controls_hint : bool;
  autosave : bool;
  tutorial_card : bool;
  choice_rows : Choice_rows.t option;  (** only with a choice box *)
}
(** What one frame shows. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** Every probe {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> t
(** The frame's readings; a missing probe reads as nothing shown. *)

val to_string : t -> string
(** The readings that show, comma-separated ("white fade, autosave");
    ["nothing"] when none do. *)
