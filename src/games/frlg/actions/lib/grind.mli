(** The ["grind"] game action: level a party member with a {!Grind_plan} until
    it reaches the goal's level. Ported from the fork's GRIND step ([GrindRun]
    in Programs/AutoStory/PokemonFRLG_AutoStoryGrind.cpp, [frlg/lean]): the
    member's level is read on its summary before the first battle and after each
    one ({!Member_level}), an unread level ends the step, a level reached
    already skips the walk out, and the step ends after the battle that reaches
    the level, with one more heal (back on the spot).

    Where it differs: it first reads the member's moves and passes at once when
    it knows the goal's move already (GamePilot's). Battles are the switch trick
    at the strategy's spot (paced for, one step and back, {!Pacing}, where the
    C++ turns in place reading the facing: GamePilot has no facing reader, and
    turning blind stepped off the grass on mGBA), healing every [heal_every]
    battles (FireRed has no HP or PP reader here, the C++'s [needs_heal()]); a
    battle answers YES to the goal's move only. The level is read in slot 1,
    where the grinder is put.

    The steps that press come as {!game_steps}, so the loop runs on a fake in
    tests. Each step raises {!Menu_input.Action_failed} when it fails. *)

type game_steps = {
  slot_of : string -> int option;  (** the species' party slot, from 1 *)
  known_moves : slot:int -> string list;  (** read on the summary *)
  level : slot:int -> int option;
      (** read on the summary; [None] when it did not read *)
  swap : int -> int -> unit;  (** two party slots trade places *)
  go_to : Checkpoints.Pose.grid -> unit;  (** walked to *)
  heal : Grind_plan.heal -> unit;  (** healed, then still at the heal place *)
  find_battle : unit -> unit;  (** paced until a wild battle starts *)
  battle : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
  log : string -> unit;
}

val run : ?cap:int -> game_steps -> Grind_plan.t -> unit
(** Logs ["Grind: battle N of LIMIT, Lv L over (...)."] after each battle. Fails
    as [not_in_party], [grind_level_unread] (before the grind or after a battle,
    as the C++ ends with UNREAD or FAILED), [grind_battle_failed] (with the
    battle's reason) or [grind_out_of_battles] after [max_battles] (the C++'s
    OUT_OF_ENCOUNTERS). With [cap] (testing: the runner's [--grind-battles]) it
    ends, passing, after that many battles below the target level, and logs
    ["Grind: capped at N battles for testing: ... is Lv L, not T"]; a
    [max_battles] below the cap still fails. The C++ has no cap: its tests ran
    capped copies of the plan. A battle where the sweeper could not come in (it
    fainted in an earlier one, the game refusing the switch) is run from, logged
    as ["Grind: battle N: SWEEPER could not come in, ran."], and a heal comes
    before the next battle; the C++ heals on [needs_heal()] instead.

    One round ({!Grind_plan.t.round}, GamePilot's, for mg-04b's repeating
    checkpoint): from the heal place to the spot, at most [heal_every] battles
    (fewer with [cap] or [max_battles]), stopping after the battle that reaches
    the target level or that the sweeper could not come in to, then a heal that
    ends at the heal place, never back to the spot, so the runner can save
    there. The goal's move is learned in whichever battle offers it. It fails as
    [grind_move_missed] when the grinder starts the round at the target level
    without the move (no later battle offers it), and passes at once, walking
    nowhere, when the grinder knows the move already. *)
