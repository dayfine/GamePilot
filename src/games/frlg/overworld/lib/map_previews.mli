(** FireRed's map preview screens: entering some dungeons from another region
    map section, the game shows a picture of the place before the map, then
    flashes white, fades to black and up again onto the map. A warp's first fade
    coming up is then the picture, not the map. From pret/pokefirered's
    [sMapPreviewScreenData] (src/map_preview_screen.c). *)

val section : string -> string option
(** The preview section a map (by name) belongs to, if its place has a preview:
    the map name prefix standing for the decomp's region map section, e.g.
    ["PokemonTower_"] for ["PokemonTower_5F"]. *)

val on_warp : from_map:string -> to_map:string -> bool
(** Whether a warp between the two maps shows a preview: the far map has one,
    and the near map is not in the same section. *)

val watch_ms : int
(** 3500: from the warp's first fade coming up, how long until the preview's own
    fade to black at the latest: its longest hold, 120 frames, and its fade in
    and out. *)

val fade_gap_ms : int
(** 1000: after the preview's first fade comes up, how long until its next one
    at the latest. The preview goes to the map through a flash of white, then
    black. *)
