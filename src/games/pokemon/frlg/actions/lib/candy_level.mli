(** The ["candy_level"] game action, the train block: Rare Candies fed to one
    member until it reaches the goal's level ({!Candy_plan.goal}), then its
    summary checked for the level, the species and the moves the goal names. It
    composes with the other plan actions: a plan can [capture] a Pokemon,
    [duplicate_item] Rare Candies, and then [candy_level] it. Not in the fork,
    whose only candy loop ([PokemonFRLG_RngLoopRoutines.cpp]) feeds candies to
    read stats for its RNG search.

    The starting level is read once on the member's summary ({!Member_level}).
    When candies are needed, the bag is opened once to Rare Candy, up to
    [min (target_level - start_level) max_candies] candies are fed in a row
    while staying in the bag, the bag is closed once, and the final summary is
    checked once. The game steps come as {!game_steps}, so the loop runs on a
    fake in tests. *)

type game_steps = {
  read_level : slot:int -> (int option, Pokemon_engine.Failure.cause) result;
      (** From the overworld: the member's level on its summary; [None] when it
          did not read, [Error] when a menu step on the way failed. *)
  open_bag : unit -> (Rare_candy.opened, Pokemon_engine.Failure.cause) result;
      (** From the overworld: opens the bag to Rare Candy. On [No_candy], the
          bag is closed back to the overworld. *)
  use_candy :
    slot:int -> Frlg_battle.Level_up_policy.policy -> Rare_candy.result;
      (** One candy while the bag is open on Rare Candy ({!Rare_candy.use_one}),
          ending back in the bag on [Used] or [Out_of_candies]. *)
  close_bag : unit -> (unit, Pokemon_engine.Failure.cause) result;
      (** From the bag, back to the overworld; [Error] as {!open_bag}. *)
  read_member :
    slot:int -> (Room_policy.member option, Pokemon_engine.Failure.cause) result;
      (** From the overworld: the member's summary read (species, level, moves);
          [None] when it did not, [Error] as {!read_level}. *)
  log : string -> unit;
}
(** The steps in the game this module can take: what it reads and does on this
    context's screens (the overworld, the summary, the bag and a candy's). *)

type report = {
  candies : int;
  level : int;  (** read on the summary at the end *)
  species : string;  (** read on the summary at the end *)
  learned : Frlg_battle.Level_up_policy.move_rule list;
  declined : string option list;
  evolutions : Frlg_battle.Level_up.evolution list;
      (** each evolution met, in order *)
}
(** Summary of a completed leveling run. *)

val run :
  game_steps ->
  Candy_plan.goal ->
  slot:int ->
  (report, Pokemon_engine.Failure.cause) result
(** Fails as [level_unread], [no_effect] (a candy did nothing: a Lv 100 member),
    [rare_candy_failed] (with the candy's reason), [out_of_candies],
    [max_candies], as a menu step's cause (the game steps' [Error] or a candy
    {!Rare_candy.Stopped}), and at the check as [no_summary], [level_short],
    [species_wrong], [moves_unread] or [moves_missing]. Passes at once, without
    opening the bag, when the starting level reads the target already; the
    summary is checked all the same. *)
