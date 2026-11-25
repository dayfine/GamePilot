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
    no probe does yet); the party bar's D-pad marker ({!Party_bar}). *)

type t = {
  fade : Screen_state.Fade.t;
  dialog_box : bool;
  choice_box : bool;
  advance_arrow : bool;
  controls_hint : bool;
      (** not in battle: the battle's own hint ("ZL: Focus on a Pokémon") sits
          where the controls hint does and can read as it *)
  autosave : bool;
  tutorial_card : bool;
  choice_rows : Choice_rows.t option;  (** only with a choice box *)
  interact_prompt : bool;
      (** an A prompt ({!Interact_prompt}), with no fade and no text box *)
  battle : bool;  (** the battle HUD ({!Battle_hud}), with no fade *)
  story_dialog : bool;
      (** a dialogue box as the fork's default [StoryDialogDetector] reads it:
          the white box with its arrow, or the blue or teal box *)
  moves : Move_symbols.symbol option list;
      (** the four moves' effectiveness symbols ({!Move_symbols}) *)
  party_bar : bool;
      (** the overworld party bar ({!Party_bar}), with no fade and no text box:
          the fork's [PLAYER_CAN_MOVE] *)
}
(** What one frame shows. *)

val probes : picture:Wire.box -> assets:Blob_assets.t -> Wire.probe_spec list
(** Every probe {!read} needs, for a game picture at [picture] in the frame. *)

val read : Effects.measurements -> t
(** The frame's readings; a missing probe reads as nothing shown. *)

val to_string : t -> string
(** The readings that show, comma-separated ("white fade, autosave");
    ["nothing"] when none do. *)
