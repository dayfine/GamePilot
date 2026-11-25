(** The count of species caught, read off the Trainer Card's front (Start menu,
    the player's name), digit by digit ({!Frlg_text.Number_reading},
    {!Frlg_text.Text_lines.trainer_card_dex_digit}). New: the fork reads no
    Pokédex count. The card shows the Kanto Pokédex's count until the National
    Pokédex is enabled (pret pokefirered src/trainer_card.c), which is the count
    Professor Oak checks for the National Pokédex (60, in
    data/maps/PalletTown_ProfessorOaksLab/scripts.inc). A save without the
    Pokédex shows no count: it reads as [None]. *)

val max_digits : int
(** 3: the most digits the count has (386 at most, the National Pokédex). *)

val read_with : int Trainer_card_read.game_steps -> int option
(** {!Trainer_card_read.read_with} for the count: two reads that agree on the
    faded-in front ({!Frlg_readers.Trainer_card_front.front_shown}). Logs
    ["Trainer Card: 10 species caught."], or
    ["Trainer Card: the Pokedex count did not read."]. *)

val read : log:(string -> unit) -> int option
(** {!read_with} on the console ({!Trainer_card_read.read}): the count on the
    latest frame. [None] when no count read in
    {!Trainer_card_read.read_timeout_ms}. Fails as [no_start_menu] or
    [not_closed]. *)
