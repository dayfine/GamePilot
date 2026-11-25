(** The Seagallop from a Sevii Islands harbor: the sailor's list of islands and
    the crossing. The story's ["ferry"] game action. Not in the fork (its story
    turns Bill down and never sails); from pokefirered
    data/scripts/seagallop.inc and src/seagallop.c.

    Only the list the Tri-Pass gives before Bill's trip back to Cinnabar is
    read: the two other islands of One, Two and Three, then EXIT
    (EventScript_ChooseDestFromOneIsland and ...FromTwoIsland,
    MULTICHOICE_ISLAND_23 and _13), which share one window
    ({!Frlg_readers.Script_menu.seagallop_islands}, measured on One Island's).
    Three Island's list (_12) is narrower, and the lists with VERMILION (once
    VAR_MAP_SCENE_CINNABAR_ISLAND reaches 4) and the Rainbow Pass's pages are
    other windows, not read yet. *)

type trip = {
  from : string;  (** The harbor's map: ["OneIsland_Harbor"]. *)
  to_ : string;  (** The island sailed to: ["TwoIsland"]. *)
  row : int;  (** Its row on the sailor's list, from 0 at the top. *)
}

val islands : (string * string list) list
(** Each harbor read and its list's islands, top first (EXIT follows). *)

val trip_of_args :
  from:string option ->
  Json_field.obj ->
  (trip, Pokemon_engine.Failure.cause) result
(** A ["ferry"] action's ["to"], sailed from the harbor the player stands in
    ([from], the reckoned map); [bad_args] when that harbor's list is not read
    or does not have the island. *)

val arrival : trip -> Pokemon_engine.Pose.observed
(** Where the crossing leaves the player: (8, 5) of the island's harbor, above
    its sailor (sSeagallopSpawnLocations), facing south. *)

val sail : log:(string -> unit) -> trip -> unit
(** Facing the sailor: A, the list read until its cursor is on the island, A,
    then the crossing settled until the harbor has faded in. Fails as
    [no_seagallop_list] when the list does not show or its cursor does not reach
    the row, [seagallop_list_open] when it stays open, or as the settle's cause.
*)

val run :
  log:(string -> unit) ->
  from:string option ->
  Json_field.obj ->
  (Pokemon_engine.Pose.observed, Pokemon_engine.Failure.cause) result
(** The ["ferry"] action: {!trip_of_args}, then {!sail}; its {!arrival} when it
    passed. *)
