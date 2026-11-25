(** The wild encounter slots of every location, by encounter type ([grass],
    [surfing], [rocksmash], [oldrod], [goodrod], [superrod]).

    Port of [EncountersDatabase] (the fork's
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_EncountersDatabase.cpp])
    reading [Resources/PokemonFRLG/EncounterSlotsFR.json] (or LG's): an object
    of types, each an object of locations, each an array of
    [{species, minLevel, maxLevel}]. *)

type t

val of_json : Yojson.Safe.t -> (t, string) result

val slots :
  t -> kind:string -> location:string -> Wild_encounter.slot array option
(** [get_nothrow] and the location's lookup: [None] for an unknown type or
    location. *)
