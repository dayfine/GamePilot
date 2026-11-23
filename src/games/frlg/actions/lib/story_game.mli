(** FireRed's story {!Story.Game.t}, as far as the overworld goes: [route] and
    [ready] events planned and walked ({!Frlg_overworld}), [talk] and [scene]
    settled ({!Talk}), and the ["fly"] game action ({!Fly}). Every other kind,
    and heal, save and reload, fail as [not_implemented] (repeats): battles and
    menus come from their own libraries.

    FireRed can't show where the player stands, so the position is reckoned: a
    walk ends on its plan's tile, a Fly on the town's landing tile, and after
    any other event that passes the player is taken to be where its
    [declared_after] says when that names one tile. *)

type config = {
  world : Frlg_overworld.Frlg_steps.world;
  gait : Frlg_overworld.Route_legs.gait;
  flee : unit -> unit;  (** Runs from a wild battle, back to the overworld. *)
  flags : string -> bool;
  log : string -> unit;
}

type t

val create : config -> start:Story.Pose.observed option -> t
(** [start]: where the player stands at the checkpoint's start, if known. *)

val game : t -> Story.Game.t

val fly_plan : Grid_maps.Json_field.obj -> (Fly.plan, string) result
(** A ["fly"] action's args: ["town"] (a {!Fly_towns.kanto} name), ["slot"]
    (from 1) and ["menu_row"] (default 2). *)
