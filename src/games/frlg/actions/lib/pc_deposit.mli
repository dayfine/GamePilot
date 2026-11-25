(** The PC deposit on the game: from the overworld facing a Pokémon Center's PC,
    each look is a frame read by {!Frlg_readers.Pc_screen}, with the labels
    {!Pc_deposit_steps} needs read by {!Frlg_text.Line_reading} (the cursor's
    row, PKMN DATA's species, the box screen's message), and each press is the
    fork's ([ConsolePcStorageActions::press()], PokemonFRLG_AutoStoryPcStorage,
    [frlg/lean]): A and B held 160 ms then 640 ms, the D-pad 160 then 320, a
    wait 500. A frame that reads as the overworld is looked at again 800 ms
    later, as the fork's [read_view()] does. Never releases: see
    {!Pc_deposit_steps}. *)

val max_presses : int -> int
(** For this many members: the fork's 80, and 40 more for each after the first.
*)

val deposit : log:(string -> unit) -> string list -> unit
(** Stores these species (slugs) in the first boxes with room, and is back on
    the overworld. Fails as [pc_deposit] naming the screen and why. *)

val look : unit -> Pc_deposit_steps.look
(** One look at the PC's screen: the view, the cursor row's label, PKMN DATA's
    species on the party panel, "The BOX is full.". A frame that reads as the
    overworld is looked at again 800 ms later. With {!Frlg_readers.Pc_screen}'s
    probes subscribed. *)

val press : Pc_deposit_steps.press -> unit
(** The fork's press: A and B held 160 ms then 640 ms, the D-pad 160 then 320, a
    wait 500. *)
