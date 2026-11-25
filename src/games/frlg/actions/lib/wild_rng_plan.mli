(** The ["wild_rng"] game action's plan: the shiny wild Pokémon to aim at, the
    trainer's IDs, the seed table and frame model to time it with, and the
    catch. The options of the fork's
    [PokemonFRLG/Programs/RngManipulation/PokemonFRLG_WildRng.cpp] (the target,
    location, species, trainer IDs, seed table and advances) as plan args; the
    seed and advance are searched for ({!Frlg_rng.Wild_target}) instead of
    given. Sweet Scent targets only, on a grass location, with the game's sound
    on Mono and its button mode on Help (the seed column ["Mono / Help / A"]).
*)

type t = {
  species : string;  (** The species to catch shiny: ["ekans"]. *)
  location : string;  (** The grass table's key: ["route_10"]. *)
  tid : int;
      (** The trainer ID: the public number on the trainer card, 0..65535. *)
  sid : int;
      (** The secret ID: the trainer's hidden second number, 0..65535; with
          [tid] it decides which PIDs are shiny. *)
  seeds : string;
      (** the seed table, a file under [src/games/frlg/assets/] in FR_Eng.json's
          shape, measured from the checkpoint's start save *)
  frame_model : string;  (** ["mgba"] or ["switch"] (Frlg_rng.Rng_timings) *)
  min_advance : int;
      (** The first RNG advance the search tries: fewer cannot be reached in
          time after the continue screen. *)
  max_advance : int;  (** The last RNG advance the search tries. *)
  capture : Capture_plan.t;
      (** the species, the ball, the balls; its encounters are the attempts *)
}

val decode : Json_field.obj -> (t, Pokemon_engine.Failure.cause) result
(** ["species"], ["location"] (["route_10"]), ["tid"], ["sid"] (0..65535),
    ["seeds"], ["frame_model"] (["mgba"]), ["advances"] ([[min, max]], default
    [[900, 4000]]), ["ball"] (["poke-ball"]), ["balls"] (5), ["attempts"] (1).
*)

val encounter_slots : string
(** The file the grass slots are read from, FireRed's:
    [src/games/frlg/assets/encounter_slots_firered.json], which
    [src/games/frlg/assets/extract/extract_frlg_encounter_slots.py] writes from
    Packages' [EncounterSlotsFR.json] (LeafGreen's beside it). *)

val target : t -> (Frlg_rng.Wild_target.t, string) result
(** Reads the seed table and the slots, and searches them: the soonest shiny
    [species] in the advance range, timed for the frame model. *)
