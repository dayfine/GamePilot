(** Wild Zone 1 on the full map: its outline, the way out by its far gate, and
    the check that the player is out. Ported from
    PokemonLZA_AutoStoryZone1.h/.cpp ([plza/lean]). *)

val rocks : Map_leg.waypoint
(** Taunie's rocks (476, 224), where 03.08 starts. *)

val road_entry : Map_leg.waypoint
(** Off the rocks onto the road, on the way to {!spot_100}. *)

val spot_100 : Map_leg.waypoint
(** The 100 spot (442, 227), stop radius 12. *)

val spot_80 : Map_leg.waypoint
(** The 80 spot (408, 234), stop radius 12: the sidewalk by the blue kiosk
    (Weedle and Pichu lawn), inside the zone and clear of its reticle ring and
    the map's centre. *)

val pin_in_zone : Map_leg.point -> bool
(** Inside the zone's outline (traced from map frames, every pin read in the
    zone so far inside it; even-odd rule), and not at the map's centre: out of
    every wild zone the map opens on the player at its centre, (401, 224) within
    3 (on the street outside the far gate the pin read (401, 223) to (401, 225);
    tight, so Weedle caught at (402, 230) stays in). *)

val at_map_centre : Map_leg.point -> bool
(** Within 3 of (401, 224). *)

val exit_legs : Map_leg.point -> Map_leg.point list
(** The points from [start] to the far gate (361, 252), between its pillars,
    where "A Leave" shows: the gate alone when [start] is east of it on its line
    (bearing 270 within 8: a run 20 off it ended on a pillar, 2026-11-17), else
    the run-up (375, 252) first. *)

val point_text : Map_leg.point -> string
(** "(401, 224)". *)

val out_of_zone_reads : int
(** 2: the pin reads {!check_out} takes at most. *)

val check_out :
  (unit -> Map_leg.point option) -> (string, Engine_run.Failure.cause) result
(** Reads the pin up to twice, stopping at the map's centre: [Ok] with the reads
    when none is in the zone; [in_wild_zone] on one in it; [zone_unread] on no
    pin. The fork's [check_out_of_zone_1]. *)
