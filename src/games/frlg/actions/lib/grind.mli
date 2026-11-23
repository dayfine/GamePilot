(** The ["grind"] game action: level a party member with a {!Grind_plan} until
    it has learned the goal's move. It first reads the member's moves and passes
    at once when it knows the move already. Otherwise it puts the grinder in
    party slot 1 and the sweeper in slot 2, goes to the strategy's spot, and
    fights wild battles there (turning in place for each), healing every
    [heal_every] battles and going back. It ends after the battle the move was
    learned in, read on the list to forget from: FireRed has no level reader, so
    the target level is not checked.

    The steps that press come as a {!rig}, so the loop runs on a fake in tests.
    Each step raises {!Menu_input.Action_failed} when it fails. *)

type rig = {
  slot_of : string -> int option;  (** the species' party slot, from 1 *)
  known_moves : slot:int -> string list;  (** read on the summary *)
  swap : int -> int -> unit;  (** two party slots trade places *)
  go_to : Story.Pose.grid -> unit;  (** walked to *)
  heal : Grind_plan.heal -> unit;  (** healed, then still at the heal place *)
  find_battle : unit -> unit;  (** turned in place until a wild battle starts *)
  battle : Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome;
  log : string -> unit;
}

val run : rig -> Grind_plan.t -> unit
(** Fails as [not_in_party], [grind_battle_failed] (with the battle's reason) or
    [grind_out_of_battles] after [max_battles]. *)
