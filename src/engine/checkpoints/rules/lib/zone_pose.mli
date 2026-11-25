(** A zone pose: a place, and maybe a spot in it, for a game whose player is not
    read on a tile grid (PLZA, Octopath 0, the engine's toy game). Where a plan
    says the player stands and where the game reads them are the same shape. Its
    plan codec is [Engine_plan_codec.Zone_pose_decode], its text
    [Engine_text.Zone_pose_text], its saved JSON [Engine_saved.Zone_saved]. *)

type t = { place : string; spot : string option }
(** A place, and maybe a spot in it. *)

type observed = t
(** Where the game reads the player: a place, and the spot when it reads one. *)

val matches : t -> observed -> bool
(** A pose without a spot holds anywhere in its place; one with a spot holds
    only on that spot. *)
