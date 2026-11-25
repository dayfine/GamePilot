(** People a scene takes away for good, who stand where no walk reaches them
    before it: the scene's own trigger tiles lie across every way to them. Its
    [removeobject] sets their hide flag and no script clears it again, so once a
    walk can reach their tiles they are gone, and a walk need not go round them.

    GamePilot's own, as {!Scene_only_people}: the fork's story walks no map with
    one. Only the ones a story walk meets are listed:

    - Three Island: the Biker goons and Cue Ball Paxton in the street north of
      the coord-event rows 26 and 27 (the Bikers' scene in pokefirered
      data/maps/ThreeIsland/scripts.inc removes all seven Bikers, with
      FLAG_HIDE_THREE_ISLAND_BIKERS and FLAG_HIDE_THREE_ISLAND_LONE_BIKER). The
      two islanders beside them (FLAG_HIDE_THREE_ISLAND_ANTIBIKERS) stay until
      Lostelle is home, so they still stand in the way. *)

val flags : string list
(** Their hide flags. *)

val hidden : Grid_maps.Map_features.map_object -> bool
(** Whether the object is one of them: its hide flag is in {!flags}. *)
