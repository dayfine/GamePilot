(** Walks by the full map's pin, and Wild Zone 1's way out. Ported from
    PokemonLZA_AutoStoryWorldWalks.cpp (the pin read on the map and the walk
    along map legs) and PokemonLZA_AutoStoryConsoleActions.cpp (the plan's
    [run_out_of_zone_1], with its [check_out_of_zone_1] from
    PokemonLZA_AutoStoryZone1.cpp).

    Where it differs: the fork keeps the pin its start check read and hands it
    to the checkpoint's first map read, which skips opening the map; here every
    read opens the map. *)

val read_pin : Walk.game_steps -> Map_leg.point option
(** + ([Plus]; 100 ms, then 1.5 s for the map to open), up to 8 looks 250 ms
      apart for the pin ({!Screen.t.map_pin}), then B (100 ms, then 1 s for it
      to close). *)

val walk_legs :
  Walk.game_steps ->
  Map_leg.waypoint list ->
  (unit, Engine_run.Failure.cause) result
(** Each waypoint in turn by {!Map_leg}, from one pin read: face the heading
    ({!Face_heading}), walk the hold (released 300 ms), read the pin again. No
    pin: a short step ahead (300 ms, released 300) and the map again, as the
    map's cursor can snap onto a badge by the player (the zone's "1" at the 60
    spot); no pin twice: [map_pin_not_read]. Still off after two corrections:
    [leg_off_target]. *)

val run_out_of_zone_one :
  Walk.game_steps -> timeout_ms:int -> (unit, Engine_run.Failure.cause) result
(** Up to 3 runs, each planned on one pin read ({!Wild_zone_one.exit_legs}):
    each leg but the last faced and run (B held, released 300 ms), then the last
    faced and run until the gate's A prompt ({!Gate_run}); a run with no prompt
    (a pillar) reads the pin again and plans from there. No pin:
    [map_pin_not_read]; no prompt after 3 runs: [gate_not_reached]. A wild
    battle does not stop it: leaving the zone ends the battle. *)

val check_out_of_zone_one :
  Walk.game_steps -> (unit, Engine_run.Failure.cause) result
(** {!Wild_zone_one.check_out} on map reads, logged. *)
