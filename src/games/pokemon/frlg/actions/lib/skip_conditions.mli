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
    - [party_slot_holds_mail:<slot>]: party slot [<slot>] (1..6) already shows
      the Mail mark on the party screen ({!Mail_glitch_use.read_marks}). For
      steps that give filler Mail to party slots.
    - [party_has_species:<slug>]: the party already holds a member of species
      [<slug>], read off the summaries ({!Party_species.read_all}). For catches
      and prize redemptions whose member (or what it trades for) is already in
      the party.
    - [bag_has_item:<slug>:<min_qty>]: the bag (or Berry Pouch for berries)
      already holds at least [<min_qty>] (>= 1) of [<slug>] ({!Bag_items.count},
      {!Berry_pouch.count}). For one-time pickups and key items.
    - [coins_at_least:<min>]: the Coin Case already holds at least [<min>] (>=
      1) coins ({!Coin_case.read}; 0 when the Coin Case is not in the bag). For
      Game Corner coin purchases.

    Any other name holds never, as before: a plan's flag the run sets by
    nothing. A condition that cannot be read holds not, either form, so its
    event runs; the log says why. *)

val pokedex_seen : string
(** ["pokedex_seen"]. *)

val pokedex_not_seen : string
(** ["pokedex_not_seen"]. *)

val party_slot_holds_mail : string
(** ["party_slot_holds_mail"]. *)

val party_has_species : string
(** ["party_has_species"]. *)

val bag_has_item : string
(** ["bag_has_item"]. *)

val coins_at_least : string
(** ["coins_at_least"]. *)

val reads_pokedex : string -> bool
(** The condition is a [pokedex_seen] or [pokedex_not_seen] one: the run loads
    the species' names to check it. *)

val reads_species : string -> bool
(** The condition names a species ([pokedex_seen], [pokedex_not_seen] or
    [party_has_species]): the run loads the species' names to check it. *)

val check_syntax : string -> (unit, string) result
(** Checks condition syntax ([party_slot_holds_mail:<slot>] in 1..6,
    [party_has_species:<slug>] non-empty, [bag_has_item:<slug>:<min_qty>] with
    [<min_qty>] >= 1, [coins_at_least:<min>] with [<min>] >= 1); any unknown
    condition name passes. *)

val check : Frlg_text.Species_names.t -> string -> (unit, string) result
(** Checks {!check_syntax}, that any [pokedex_seen] or [pokedex_not_seen]
    condition names a Kanto species by its slug, and that any
    [party_has_species] condition names a FireRed species by its slug; any other
    name passes. *)

val answer :
  seen:bool ->
  (Pokedex_entry.entry, Pokemon_engine.Failure.cause) result ->
  string * bool
(** What the log says of the Pokédex's entry, and whether the condition holds:
    with [~seen:true] ([pokedex_seen]) when the entry is seen or caught, with
    [~seen:false] ([pokedex_not_seen]) when it is not seen; neither when the
    entry did not read. *)

val mail_answer :
  slot:int ->
  (Frlg_readers.Party_menu.mark list, Pokemon_engine.Failure.cause) result ->
  string * bool
(** What the log says of party slot [slot]'s mark, and whether it is
    [Party_menu.Mail]; [false] when the slot is empty or the party did not read.
*)

val species_answer :
  species:string ->
  (string option list, Pokemon_engine.Failure.cause) result ->
  string * bool
(** What the log says of whether [species] is among the party's read species,
    and whether the condition holds; [false] when the party did not read. *)

val bag_answer :
  min_qty:int ->
  (int option, Pokemon_engine.Failure.cause) result ->
  string * bool
(** What the log says of an item's bag count, and whether it is at least
    [min_qty]; [false] when the count did not read. *)

val coins_answer :
  min:int -> (int option, Pokemon_engine.Failure.cause) result -> string * bool
(** What the log says of the Coin Case's coin count, and whether it is at least
    [min]; [false] when the count did not read. *)

val holds : log:(string -> unit) -> string -> bool
(** Reads the condition from the game, in the effect context, from the
    overworld; logs ["[Skip] pokedex_seen:magikarp: seen."]. *)

val remembered : (string -> 'a) -> string -> 'a
(** [remembered read]: [read], asked at most once per key (a condition, a
    species); later asks get the first answer. *)

val read_once : log:(string -> unit) -> string -> bool
(** {!holds}, each game read cached for the checkpoint run: each species'
    Pokédex entry once, the party's marks once, the party's species once, each
    bag item's count once, and the Coin Case's coins once. A checkpoint run asks
    for a fresh one, so each read happens before the first event whose condition
    names it and keeps that answer to the end of the run;
    [pokedex_seen:magikarp] and [pokedex_not_seen:magikarp] share the one read.
    One read instead of one per event, and an event that changes the answer
    (buying the Magikarp a later event's [pokedex_seen:magikarp] names) does not
    skip the events after it. *)
