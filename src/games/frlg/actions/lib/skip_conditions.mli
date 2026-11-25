(** The [skip_if] conditions FireRed reads from the game: an event is skipped
    when the game already holds its result (review rule R5). A condition is
    [<kind>:<argument>]:

    - [pokedex_seen:<species>]: the Kanto Pokédex has the species seen (or
      caught), read off its list ({!Pokedex_entry_steps}). For a step that is
      there only to see a species (a word the Easy Chat lists once its species
      is seen).

    Any other name holds never, as before: a plan's flag the run sets by
    nothing. A condition that cannot be read holds not, so its event runs; the
    log says why. *)

val pokedex_seen : string
(** ["pokedex_seen"]. *)

val check : Frlg_text.Species_names.t -> string -> (unit, string) result
(** A [pokedex_seen] condition names a Kanto species by its slug; any other name
    passes. *)

val holds : log:(string -> unit) -> string -> bool
(** Reads the condition from the game, in the effect context, from the
    overworld; logs ["[Skip] pokedex_seen:magikarp: seen."]. *)
