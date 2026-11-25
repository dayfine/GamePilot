(** The ["wild_rng"] game action's plan: the shiny wild Pokémon to aim at, the
    trainer's IDs, the seed table and frame model to time it with, and the
    catch. The fork's WildRng options ([TARGET], [LOCATION], [SPECIES], [TID],
    [SID], [SEED_TABLE], the advances) as plan args; the seed and advance are
    searched for ({!Frlg_rng.Wild_target}) instead of given. Sweet Scent only
    (the fork's [sweetscent] target), on a grass location, Mono and Help (the
    seed column ["Mono / Help / A"]). *)

type t = {
  species : string;  (** ["ekans"] *)
  location : string;  (** the grass table's key: ["route_10"] *)
  tid : int;
  sid : int;
  seeds : string;
      (** the seed table, a file under [src/games/frlg/assets/] in FR_Eng.json's
          shape, measured from the checkpoint's start save *)
  frame_model : string;  (** ["mgba"] or ["switch"] (Frlg_rng.Rng_timings) *)
  min_advance : int;
  max_advance : int;
  capture : Capture_plan.t;
      (** the species, the ball, the balls; its encounters are the attempts *)
}

val decode : Json_field.obj -> (t, Pokemon_engine.Failure.cause) result
(** ["species"], ["location"] (["route_10"]), ["tid"], ["sid"] (0..65535),
    ["seeds"], ["frame_model"] (["mgba"]), ["advances"] ([[min, max]], default
    [[900, 4000]]), ["ball"] (["poke-ball"]), ["balls"] (5), ["attempts"] (1).
*)

val encounter_slots : string
(** The fork's resource the grass slots come from:
    [third_party/Packages/Resources/PokemonFRLG/EncounterSlotsFR.json]. *)

val target : t -> (Frlg_rng.Wild_target.t, string) result
(** Reads the seed table and the slots, and searches them: the soonest shiny
    [species] in the advance range, timed for the frame model. *)
