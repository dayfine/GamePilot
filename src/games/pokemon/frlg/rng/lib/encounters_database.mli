(** The wild encounter slots of every location, by encounter type ([grass],
    [surfing], [rocksmash], [oldrod], [goodrod], [superrod]).

    Port of the fork's
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_EncountersDatabase.cpp],
    reading [src/games/pokemon/frlg/assets/encounter_slots_firered.json] (or
    LeafGreen's), Packages' slots in the same shape: an object of types, each an
    object of locations, each an array of [{species, minLevel, maxLevel}]. *)

type t
(** Every location's slots, by encounter type. *)

val of_json : Yojson.Safe.t -> (t, string) result
(** The slots file's object; Error naming the first entry not in its shape. *)

val slots :
  t -> kind:string -> location:string -> Wild_encounter.slot array option
(** The slots of one location for one encounter type: [None] for an unknown type
    or location. *)
