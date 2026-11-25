(** The count of species caught, read off the Trainer Card's front (Start menu,
    the player's name), digit by digit ({!Frlg_text.Number_reading},
    {!Frlg_text.Text_lines.trainer_card_dex_digit}). New: the fork reads no
    Pokédex count. The card shows the Kanto Pokédex's count until the National
    Pokédex is enabled (pret pokefirered src/trainer_card.c), which is the count
    Professor Oak checks for the National Pokédex (60, in
    data/maps/PalletTown_ProfessorOaksLab/scripts.inc). A save without the
    Pokédex shows no count: it reads as [None]. *)

val max_digits : int
(** 3. *)

val read : log:(string -> unit) -> int option
(** From the overworld: the card opened, its count read on the card's front
    ({!Frlg_readers.Trainer_card_front.front_shown}) until two reads
    {!reread_ms} apart agree, as {!Trainer_card_badges} reads (the card fades
    in, and a B pressed then is lost: mGBA, 02-route10-new-species verification
    run 1), then {!Trainer_card_money.close}. [None] when no count read in
    {!Trainer_card_money.read_timeout_ms}. Fails as [no_start_menu] or
    [not_closed]. *)

val reread_ms : int
(** 300 ms between reads. *)
