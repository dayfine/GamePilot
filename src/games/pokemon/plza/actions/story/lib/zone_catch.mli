(** Wild Zone 1's catches for the fourth and fifth species (03.10, 03.11), the
    plan's [catch_in_zone]: ported from PokemonLZA_AutoStoryCatches.cpp (with
    its party slot count and its way to a zone spot), 12 throws as the fork's
    (PokemonLZA_AutoStoryConsoleActions.cpp).

    The party bar's count (settled, {!Catch_plan.settled_party_slots}, looks 250
    ms apart) decides the catch: 5 or more, nothing to catch; 4, the fifth at
    the 80 spot ({!Plza_walk.Wild_zone_one.spot_80}; a walk there by the map,
    {!Plza_walk.Map_walk.walk_legs}); else the fourth at the 100 spot
    ({!Plza_walk.Wild_zone_one.spot_100}), from Taunie's rocks: the map's pin
    must be within 8 of the rocks, else [chain_off_start] ("rocks not left", off
    its start as a start check is, so the run reloads), then L (100 ms, released
    150), the left stick left 900 ms (released 300) off the rocks, and the map's
    legs by the road entry to the spot. At the spot
    {!Zone_throws.catch_at_stop}. Done when the party reaches its target (read
    again after throws); else [short_of_species]. *)

val max_throws : int
(** 12. *)

val run : Steps.game_steps -> max_throws:int -> Steps.outcome
(** The catch, up to [max_throws] throws, as above. *)
