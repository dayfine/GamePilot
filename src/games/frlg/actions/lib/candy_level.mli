(** The ["candy_level"] game action, the train block: Rare Candies fed to one
    member, one {!Rare_candy} at a time, until its level reads the goal's
    ({!Candy_plan.goal}), then its summary checked for the level, the species
    and the moves the goal names. It composes with the other plan actions: a
    plan can [capture] a Pokemon, [duplicate_item] Rare Candies, and then
    [candy_level] it. Not in the fork, whose only candy loop
    ([PokemonFRLG_RngLoopRoutines.cpp]) feeds candies to read stats for its RNG
    search.

    The level is read on the member's summary ({!Member_level}) before the first
    candy and after each: each candy must raise it, and the feeding stops as
    soon as it reads the target. The game steps come as a {!rig}, so the loop
    runs on a fake in tests. *)

type rig = {
  level : slot:int -> int option;
      (** From the overworld: the member's level on its summary; [None] when it
          did not read. *)
  candy : slot:int -> Candy_plan.use -> Rare_candy.result;
      (** One candy, from the overworld back to it ({!Rare_candy.run}). *)
  member : slot:int -> Story.Room_policy.member option;
      (** From the overworld: the member's summary read (species, level, moves);
          [None] when it did not. *)
  log : string -> unit;
}

type report = {
  candies : int;
  level : int;  (** read before the summary check *)
  species : string;  (** read on the summary at the end *)
  learned : Candy_plan.move_rule list;
  declined : string option list;
  evolutions : Rare_candy.evolution list;  (** each evolution met, in order *)
}

val run :
  rig -> Candy_plan.goal -> slot:int -> (report, Story.Failure.cause) result
(** Fails as [level_unread], [level_stuck] (a candy that did not raise the level
    read), [no_effect] (the candy did nothing: a Lv 100 member),
    [rare_candy_failed] (with the candy's reason), [out_of_candies],
    [max_candies], and at the check as [no_summary], [level_short],
    [species_wrong], [moves_unread] or [moves_missing]. Passes at once, with no
    candy, when the level reads the target already; the summary is checked all
    the same. *)
