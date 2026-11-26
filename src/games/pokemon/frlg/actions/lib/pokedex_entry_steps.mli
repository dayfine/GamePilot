(** {!Pokedex_entry}'s steps in the game: the Start menu's POKéDEX row found by
    its name ({!Start_menu_names}), the table of contents and the list told
    apart by {!Frlg_readers.Pokedex_list}, the list's numbers and names read
    with the game's font ({!Frlg_text.Text_lines.pokedex_list_number_digit},
    {!Frlg_text.Text_lines.pokedex_list_name}), and the way out as the Trainer
    Card's: B to the contents, B through the fade to the Start menu, the menu
    closed and the talk settled.

    English only: the Start menu's POKéDEX row, the species' names
    (species_names_eng) and the dashes of a species not seen are matched as the
    English game prints them, at positions measured on the English game. Another
    language needs its own names and a check of the positions. *)

val open_timeout_ms : int
(** How long the contents may take to fade in after POKéDEX's A: 5 s. *)

val settle_ms : int
(** The wait after the contents show, before the A on NUMERICAL MODE or the B
    that closes them: 300 ms. Without it, the B that closes them came right
    after the B that left the list, and the game took the two as one held B
    (mGBA, 2026-11-25: the Pokédex stayed on its contents). *)

val look_timeout_ms : int
(** How long a look waits for the arrow and its number to read the same twice: 3
    s. *)

val reread_ms : int
(** Between those two reads: 100 ms. *)

val make : log:(string -> unit) -> Pokedex_entry.game_steps
(** English screens only (see above). In the effect context, with
    {!Frlg_readers.Pokedex_list.probes} and the menu actions' probes subscribed.
    Fails ({!Menu_input.fail}) as [no_start_menu], [no_pokedex] (no POKéDEX row,
    or the Pokédex does not show) or [not_closed]. *)

val read :
  log:(string -> unit) ->
  string ->
  (Pokedex_entry.entry, Pokemon_engine.Failure.cause) result
(** The species' entry, by its slug, on the console ({!Pokedex_entry.read_with}
    on {!make}, through {!Menu_step.result}). [Error] as [not_in_kanto_pokedex]
    for a slug that is no Kanto species, as [pokedex_unread] when the list did
    not read, or as the step's cause. *)
