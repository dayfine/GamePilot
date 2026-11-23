(** FireRed's {!Screen_state.Facts.t} from one frame, as the fork's
    FrlgScreenObserver (Programs/AutoStory/PokemonFRLG_AutoStoryScreenEvents)
    builds its screen events: black corners (a dark cave) show nothing; a fade
    hides everything else; a battle hides the dialog box under it. *)

val fade_id : string

val probes : Wire.probe_spec list
(** The fade probe ({!Screen_state.Fade.middle_box} of the picture), then
    {!Dark_corners}, {!Dialog} and {!Battle_screen}'s probes. *)

val of_measurements : Effects.measurements -> Screen_state.Facts.t
(** [fade], [dialog] (the white box, with or without a Yes/No box) and [battle].
    The rest ([banner], [free_control], [screen_still], [player_still]) need
    more than one frame or other readers and stay false. *)
