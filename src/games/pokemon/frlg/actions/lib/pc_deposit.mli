(** The PC deposit on the game: from the overworld facing a Pokémon Center's PC,
    each look is a frame read by {!Frlg_readers.Pc_screen}, with the labels
    {!Pc_deposit_steps} needs read by {!Frlg_text.Line_reading} (the cursor's
    row, PKMN DATA's species, the box screen's message), and each press is the
    fork's ([ConsolePcStorageActions::press()], PokemonFRLG_AutoStoryPcStorage,
    [frlg/lean]): A and B held 160 ms then 640 ms, the D-pad 160 then 320, a
    wait 500. A frame that reads as the overworld is looked at again 800 ms
    later, as the fork's [read_view()] does. Never releases: see
    {!Pc_deposit_steps}.

    Language: PC menu labels, messages and species names are matched as English
    text; non-English ROMs need localized candidate strings. *)

val max_presses : int -> int
(** For this many members: the fork's 80, and 40 more for each after the first.
*)

val deposit : log:(string -> unit) -> string list -> unit
(** Stores these species (slugs) in the first boxes with room, and is back on
    the overworld. Fails as [pc_deposit] naming the screen and why. *)

val label : Frlg_readers.Pc_screen.view -> string option
(** The text of the cursor's row on the PC list, the storage menu or a Pokémon's
    menu (STORE or WITHDRAW first), when it reads. *)

val species_shown : unit -> string option
(** The species slug PKMN DATA shows (["/MAGIKARP"]), on any box screen, when it
    reads. *)

val look : unit -> Pc_deposit_steps.look
(** One look at the PC's screen: the view, the cursor row's label, PKMN DATA's
    species on the party panel, "The BOX is full.". A frame that reads as the
    overworld is looked at again 800 ms later. With {!Frlg_readers.Pc_screen}'s
    probes subscribed. Also {!Pc_box}'s look. *)

val press : Pc_deposit_steps.press -> unit
(** The fork's press: A and B held 160 ms then 640 ms, the D-pad 160 then 320, a
    wait 500. Also {!Pc_box}'s press. *)
