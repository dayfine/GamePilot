(** Reader: the Yes/No box the Easy Chat mail editor shows after START ("The
    MAIL message is as shown. Okay?"), and which answer its arrow is on. Ported
    from the fork's Programs/Farming/PokemonFRLG_ItemDuplication.cpp, which
    watches for the selection arrow
    (Inference/PokemonFRLG_SelectionArrowDetector.cpp) in the box (0.729, 0.460,
    0.029, 0.076) of the game picture: that is YES here. The box sits right of
    the white text box's Yes/No ({!Dialog.yes_no_cursor}, at the confirmation
    menu's arrow places in that detector file), so that reader misses it.

    Where it differs: the fork matches the arrow's template; here
    {!Cursor_column} counts the arrow's dark pixels in that box and in a NO box
    one row below it (the YES-to-NO step of the confirmation menu's boxes,
    0.0875), so an arrow on NO reads as NO, not as no box. *)

val probes : Wire.probe_spec list

val yes_box : Wire.box
(** The fork's [mail_confirmation_arrow_box]. *)

val confirm_arrow : Effects.measurements -> bool option
(** [Some true] with the arrow on YES, [Some false] on NO, [None] with no clear
    arrow (no box). *)
