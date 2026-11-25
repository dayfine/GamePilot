(** A lock-on found by sweeping the camera: ported from
    PokemonLZA_LockOnSweep.cpp ([plza/lean]). Each of [rounds] rounds: the right
    stick at ([camera_x], 0) for 1 s, D-pad up (160 ms) at its start, ZL mashed
    through that second, then ZL held 500 ms; after the rounds, L (160 ms,
    released 160) puts the camera behind the player. The rounds end at the first
    read with a move symbol (ZL locked on).

    Where it differs: the fork's watcher wants a symbol held 100 ms; here the
    first read with one ends the sweep, as {!Lock_on}. The mash is ZL 40 ms on,
    40 ms off, as {!Story_battle}'s camera turn. *)

val round_inputs : camera_x:float -> Wire.command list
(** One round's inputs. *)

val run : Story_steps.game_steps -> camera_x:float -> rounds:int -> bool
(** The sweep; whether the move symbols showed. *)
