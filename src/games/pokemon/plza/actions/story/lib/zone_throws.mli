(** The zone catches at one stop: throws at the chosen target, the wild battles
    a throw or the stop brings, and the camera. Ported from
    PokemonLZA_AutoStoryCatches.cpp.

    Where it differs: the fork races the throw against a party bar watcher (the
    bar at the target count for 250 ms ends it at once). The party count takes
    two frames here ({!Steps.game_steps.read_party_slots}), so the throw's
    inputs (ZL 500 ms, ZL and ZR 1.5 s) are sent, then the count is read over
    the throw's 8 s: reaching the target on reads 250 ms apart ends it there. *)

type result = {
  throws : int;
  caught : bool;
  party_reached : bool;  (** the party bar showed the target count *)
}

val catch_at_stop :
  Steps.game_steps -> spot:string -> max_throws:int -> party:int -> result
(** Up to 4 tries at the stop, until caught or [max_throws]: a wild battle on is
    fought back (a caught species fought off, else weakened and thrown at); else
    the camera sweeps for a lock-on ({!Lock_on_sweep}, right 0.5, 8 rounds; none
    ends the stop), the plates are read and the target chosen and approached
    ({!Zone_aim}); with only caught species, the camera turns right (0.5, 400
    ms, released 300) and tries again; else throws at the target (3 at most at
    one lock before moving on). The camera is levelled before each try after a
    lock-on, and at the end when nothing was caught. [party] is the count the
    party bar reaches on a catch. *)
