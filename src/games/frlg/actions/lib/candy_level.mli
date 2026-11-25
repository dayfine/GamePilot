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
    soon as it reads the target. The game steps come as {!game_steps}, so the
    loop runs on a fake in tests. *)

type game_steps = {
  level : slot:int -> (int option, Story.Failure.cause) result;
      (** From the overworld: the member's level on its summary; [None] when it
          did not read, [Error] when a menu step on the way failed. *)
  candy : slot:int -> Level_up_policy.policy -> Rare_candy.result;
      (** One candy, from the overworld back to it ({!Rare_candy.run}). *)
  member :
    slot:int -> (Story.Room_policy.member option, Story.Failure.cause) result;
      (** From the overworld: the member's summary read (species, level, moves);
          [None] when it did not, [Error] as {!level}. *)
  log : string -> unit;
}
(** The steps in the game this module can take: what it reads and does on this
    context's screens (the overworld, the summary and a candy's). *)

type report = {
  candies : int;
  level : int;  (** read before the summary check *)
  species : string;  (** read on the summary at the end *)
  learned : Level_up_policy.move_rule list;
  declined : string option list;
  evolutions : Level_up.evolution list;  (** each evolution met, in order *)
}

val run :
  game_steps ->
  Candy_plan.goal ->
  slot:int ->
  (report, Story.Failure.cause) result
(** Fails as [level_unread], [level_stuck] (a candy that did not raise the level
    read), [no_effect] (the candy did nothing: a Lv 100 member),
    [rare_candy_failed] (with the candy's reason), [out_of_candies],
    [max_candies], as a menu step's cause (the game steps' [Error] or a candy
    {!Rare_candy.Stopped}), and at the check as [no_summary], [level_short],
    [species_wrong], [moves_unread] or [moves_missing]. Passes at once, with no
    candy, when the level reads the target already; the summary is checked all
    the same. *)
