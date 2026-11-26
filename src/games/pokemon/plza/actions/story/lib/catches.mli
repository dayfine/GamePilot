(** The story's first catches, in Wild Zone 1 (03.07), the plan's
    [catch_tutorial] and [battle_then_catch]: ported from
    PokemonLZA_AutoStoryCatches.cpp, with the fork's counts (6 throws, 6 rounds,
    PokemonLZA_AutoStoryConsoleActions.cpp).

    A throw is the story's ({!Ball_throw}): ZL 500 ms to lock on, ZL and ZR 1.5
    s, then 8 s for the ball (the new member joins the party bar 6 to 7 s after
    a catch). The lines after it are passed with A ({!Press_through_lines}:
    quiet 3 s, 30 s at most). A wild battle is on while the Run prompt or the
    alert eye shows ({!Look.wild_battle_on}).

    [weaken_target]: up to 12 attacks until 3 land ({!Battle}'s attack); two
    misses in a row press D-pad up (100 ms, released 2 s; twice at most: the
    partner may not be out) and start the count afresh, so the story battle's
    camera turn after three never comes (it lost the attacker for 2 s, console
    B, 2026-11-19).

    Where it differs: the fork reads [wild_battle_on] from a snapshot after the
    inputs; here from the next read. *)

val catch_tutorial : Steps.game_steps -> max_throws:int -> Steps.outcome
(** Throws until a tutorial card shows in the lines after one (caught); a throw
    that breaks out into a wild battle (not the last) weakens the target and
    passes the lines before the next. [no_catch] after [max_throws]. *)

val battle_then_catch : Steps.game_steps -> max_rounds:int -> Steps.outcome
(** A (160 ms, released 840), the lines, D-pad up (the partner out); then each
    round weakens the target, passes the lines, throws and passes the lines
    again. A round after the first in which no attack landed: with no wild
    battle on, caught; else the camera sweeps right ({!Lock_on_sweep}, x 0.5, 8
    rounds) and, finding nothing, the round ends there. [still_a_target] after
    [max_rounds]. *)
