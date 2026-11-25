(** The [skip_if] conditions FireRed reads from the game: an event is skipped
    when the game already holds its result (review rule R5). A condition is
    [<kind>:<argument>]:

    - [pokedex_seen:<species>]: the Kanto Pokédex has the species seen (or
      caught), read off its list ({!Pokedex_entry_steps}). For a step that is
      there only to see a species (a word the Easy Chat lists once its species
      is seen).
    - [pokedex_not_seen:<species>]: the same read, the other answer: the species
      is not seen. For a step that stands in for the ones a [pokedex_seen] skips
      (ACE setup 01 withdraws a Pokémon from the PC when Magikarp is seen and
      the purchase is skipped).

    Any other name holds never, as before: a plan's flag the run sets by
    nothing. A condition that cannot be read holds not, either form, so its
    event runs; the log says why. *)

val pokedex_seen : string
(** ["pokedex_seen"]. *)

val pokedex_not_seen : string
(** ["pokedex_not_seen"]. *)

val reads_pokedex : string -> bool
(** The condition is a [pokedex_seen] or [pokedex_not_seen] one: the run loads
    the species' names to check it. *)

val check : Frlg_text.Species_names.t -> string -> (unit, string) result
(** A [pokedex_seen] or [pokedex_not_seen] condition names a Kanto species by
    its slug; any other name passes. *)

val answer :
  seen:bool ->
  (Pokedex_entry.entry, Pokemon_engine.Failure.cause) result ->
  string * bool
(** What the log says of the Pokédex's entry, and whether the condition holds:
    with [~seen:true] ([pokedex_seen]) when the entry is seen or caught, with
    [~seen:false] ([pokedex_not_seen]) when it is not seen; neither when the
    entry did not read. *)

val holds : log:(string -> unit) -> string -> bool
(** Reads the condition from the game, in the effect context, from the
    overworld; logs ["[Skip] pokedex_seen:magikarp: seen."]. *)
