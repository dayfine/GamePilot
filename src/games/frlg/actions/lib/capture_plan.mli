(** The ["capture"] game action's plan: what it catches and its bounds. Ported
    from the fork's CapturePlan and capture_plan_of()
    (Programs/AutoStory/PokemonFRLG_AutoStoryCaptureStep, _AutoStoryCapture).
    Pure.

    Left out: the fork's weakening move (["move"], ["turns"]). Its console never
    weakens, for want of a reader of the wild Pokémon's HP bar
    (ConsoleCaptureActions::read_foe_hp() reads UNKNOWN), and no plan names one,
    so an action that does fails as [bad_args]. *)

type t = {
  species : string;  (** a slug: ["spearow"] *)
  catches : int;  (** how many to catch *)
  max_encounters : int;  (** wild battles, of any species, before giving up *)
  max_balls : int;  (** Poké Balls thrown before giving up *)
  pace : Grid_geometry.Direction.t;
      (** the way to step for a battle, and back ({!Pacing}) *)
}

val decode : Json_field.obj -> (t, Pokemon_checkpoints.Failure.cause) result
(** ["species"] (required), ["catches"] (1, 1..999), ["encounters"] (20,
    1..9999), ["balls"] (5, 1..999), ["pace"] (east), as the fork reads them. *)

val describe : t -> string
(** ["1 spearow, 50 encounters, 10 balls"]. *)
