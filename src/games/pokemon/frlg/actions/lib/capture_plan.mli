(** The ["capture"] game action's plan: what it catches, with which ball, and
    its bounds. Ported from the fork's CapturePlan and its reading of a plan's
    args (Programs/AutoStory/PokemonFRLG_AutoStoryCaptureStep,
    _AutoStoryCapture). Pure.

    Where it differs:
    - The target may be the species the Pokédex has not caught ([uncaught]), for
      collecting species: new, as the fork catches one named species.
    - The ball is the plan's ([ball]): the fork throws Poké Balls only.
    - Left out: the fork's weakening move (["move"], ["turns"]). Its console
      never weakens, for want of a reader of the wild Pokémon's HP bar, and no
      plan names one, so an action that does fails as [bad_args]. *)

(** What the capture throws at. *)
type target =
  | Species of string  (** a slug: ["spearow"] *)
  | Uncaught of string list
      (** any species without the caught mark ({!Frlg_readers.Caught_mark}); the
          list is the patch's species, which the battle's first line is read
          against to name the catch (one not in it is caught unnamed) *)

type t = {
  target : target;
  catches : int;  (** how many to catch: of the species, or new species *)
  max_encounters : int;  (** wild battles, of any species, before giving up *)
  max_balls : int;  (** balls thrown before giving up *)
  ball : string;  (** the ball's slug: one of {!balls} *)
  pace : Grid_geometry.Direction.t;
      (** the way to step for a battle, and back ({!Pacing}) *)
}

val default_ball : string
(** ["poke-ball"], the fork's. *)

val balls : string list
(** The balls a Mart sells: ["poke-ball"], ["great-ball"], ["ultra-ball"]. *)

val read : where:string -> Json_field.obj -> t
(** {!decode}'s reader, for an action whose args hold a capture's
    (["wild_rng"]). It fails with [Json_field.Invalid]. *)

val decode : Json_field.obj -> (t, Pokemon_engine.Failure.cause) result
(** ["species"] or ["uncaught"] (a list of slugs, maybe empty), not both;
    ["catches"] (1, 1..999), ["encounters"] (20, 1..9999), ["balls"] (5,
    1..999), ["ball"] (["poke-ball"]), ["pace"] (east). *)

val target_name : target -> string
(** ["spearow"], or ["uncaught species"]. *)

val describe : t -> string
(** ["1 spearow, 50 encounters, 10 poke-ball"]. *)
