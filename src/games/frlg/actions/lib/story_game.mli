(** FireRed's story {!Story.Game.t}: [route] and [ready] events planned and
    walked ({!Frlg_overworld}), [talk] and [scene] settled ({!Talk}), [heal] and
    [save] events ({!Heal_and_save}), the ["fly"] game action ({!Fly}) and the
    shared ones ({!Game_actions}). Battles and the other built-in kinds fail as
    [not_implemented] (repeats): they come from their own libraries.

    Between loop rounds, heal walks to the configured Center's nurse and talks
    to her, save saves from the Start menu, and reload is the program's (an
    emulator loads a state; a console would soft reset).

    FireRed can't show where the player stands, so the position is reckoned: a
    walk ends on its plan's tile, a Fly on the town's landing tile, and after
    any other event that passes the player is taken to be where its
    [declared_after] says when that names one tile. The party is reckoned too
    ({!Party_roster}), from the config's. *)

type config = {
  world : Frlg_overworld.Frlg_steps.world;
  gait : Frlg_overworld.Route_legs.gait;
  flee : unit -> unit;  (** Runs from a wild battle, back to the overworld. *)
  flags : string -> bool;
  party : Party_roster.t;  (** The party at the checkpoint's start. *)
  center : string option;
      (** The town whose Pokémon Center heals between loop rounds
          (["LavenderTown"]); [None]: heal fails as [not_implemented]. *)
  reload : unit -> (unit, Story.Failure.cause) result;
      (** Back to the checkpoint's start state. *)
  log : string -> unit;
}

type t

val create : config -> start:Story.Pose.observed option -> t
(** [start]: where the player stands at the checkpoint's start, if known. *)

val game : t -> Story.Game.t

val party : t -> Party_roster.t
(** The party as reckoned now. *)

val fly_plan :
  Party_roster.t -> Grid_maps.Json_field.obj -> (Fly.plan, string) result
(** A ["fly"] action's args: ["town"] (a town of {!Fly_towns.load}), the Fly
    user as ["slot"] (from 1) or ["species"] (found in the party), and
    ["menu_row"] (default 2). *)
