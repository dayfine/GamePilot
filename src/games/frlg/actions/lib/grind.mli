(** The ["grind"] game action: level a party member with a {!Grind_plan} until
    it reaches the goal's level. Ported from the fork's GRIND step ([GrindRun]
    in Programs/AutoStory/PokemonFRLG_AutoStoryGrind.cpp, [frlg/lean]): the
    member's level is read on its summary before the first battle and after each
    one ({!Member_level}), an unread level ends the step, a level reached
    already skips the walk out, and the step ends after the battle that reaches
    the level, with one more heal (back on the spot).

    Where it differs: it first reads the member's moves and passes at once when
    it knows the goal's move already (GamePilot's). Battles are the switch trick
    at the strategy's spot (turning in place for each), healing every
    [heal_every] battles (FireRed has no HP or PP reader here, the C++'s
    [needs_heal()]); a battle answers YES to the goal's move only. The level is
    read in slot 1, where the grinder is put.

    The steps that press come as a {!rig}, so the loop runs on a fake in tests.
    Each step raises {!Menu_input.Action_failed} when it fails. *)

type rig = {
  slot_of : string -> int option;  (** the species' party slot, from 1 *)
  known_moves : slot:int -> string list;  (** read on the summary *)
  level : slot:int -> int option;
      (** read on the summary; [None] when it did not read *)
  swap : int -> int -> unit;  (** two party slots trade places *)
  go_to : Story.Pose.grid -> unit;  (** walked to *)
  heal : Grind_plan.heal -> unit;  (** healed, then still at the heal place *)
  find_battle : unit -> unit;  (** turned in place until a wild battle starts *)
  battle : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
  log : string -> unit;
}

val run : ?cap:int -> rig -> Grind_plan.t -> unit
(** Logs ["Grind: battle N of LIMIT, Lv L over (...)."] after each battle. Fails
    as [not_in_party], [grind_level_unread] (before the grind or after a battle,
    as the C++ ends with UNREAD or FAILED), [grind_battle_failed] (with the
    battle's reason) or [grind_out_of_battles] after [max_battles] (the C++'s
    OUT_OF_ENCOUNTERS). With [cap] (testing: the runner's [--grind-battles]) it
    ends, passing, after that many battles below the target level, and logs
    ["Grind: capped at N battles for testing: ... is Lv L, not T"]; a
    [max_battles] below the cap still fails. The C++ has no cap: its tests ran
    capped copies of the plan. *)
