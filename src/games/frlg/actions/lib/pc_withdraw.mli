(** The PC withdraw on the game ({!Pc_withdraw_steps}): from the overworld
    facing a Pokémon Center's PC, each look is a frame read by
    {!Frlg_readers.Pc_screen} and {!Frlg_readers.Pc_box_screen}'s PKMN DATA
    panel, with the row labels and the panel's species read as {!Pc_deposit}
    reads them; each press is {!Pc_deposit.press}. New: the fork has no
    withdraw. *)

val withdraw : log:(string -> unit) -> string
(** Moves the first Pokémon found in the box the PC opens on into the party, and
    is back on the overworld; its species (a slug). Fails as [pc_withdraw]
    naming the screen and why. *)
