(** People the game shows only during a scene: pret's new game sets their hide
    flag (pokefirered EventScript_ResetAllMapFlags in data/event_scripts.s at
    ce6406d8), no script clears it, and a scene shows them with [addobject] and
    takes them away with [removeobject], which sets the flag again. Outside
    their scene they are never there, so a walk need not go round them.

    GamePilot's own: the fork's story walks no map with one. Only the ones a
    story walk meets are listed:

    - Two Island's Joyful Game Corner: the Biker on its door tile (5, 8), shown
      by the owner's scene (TwoIsland_JoyfulGameCorner_EventScript_
      HelpFindLostelleScene), FLAG_HIDE_TWO_ISLAND_GAME_CORNER_BIKER. *)

val flags : string list
(** Their hide flags. *)

val hidden : Grid_maps.Map_features.map_object -> bool
(** Whether the object is one of them: its hide flag is in {!flags}. The
    {!Frlg_steps.world}'s [hidden]. *)
