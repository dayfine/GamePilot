(** The ["use_rare_candy"] game action: one Rare Candy from the bag on a party
    member, then whatever its level brings ({!Level_up}, on the party menu's
    game steps), back to the overworld. Ported from upstream's
    [use_rare_candy()] (Programs/RngManipulation/PokemonFRLG_RngNavigation.cpp):
    the bag, A on the candy until the party shows, the slot, A until the
    level-up stats show, then until the bag is back, answering each move-learn
    prompt (B, A: NO, then YES to stop) and each evolution (B) on the way. The
    game's steps come as {!game_steps}, so the decisions run on a fake in tests;
    {!Rare_candy_steps} is the game's.

    What one candy shows, in order (pokefirered party_menu.c,
    [ItemUseCB_RareCandy] on; evolution_scene.c; item_use.c
    [FieldUseFunc_RareCandy]):
    + On a Lv 100 member, "It won't have any effect." and the party closes back
      to the bag: nothing else.
    + "<MON> was elevated to Lv. <L>." with the level-up fanfare; A (or B), the
      stats window's page 1 (each stat's rise); A, page 2 (the totals); A closes
      it ([Task_DisplayLevelUpStatsPg1], [Pg2], [Task_TryLearnNewMoves]).
    + Then each move the species learns at that level, in learnset order
      ([MonTryLearningNewMove]: the first call finds the level's first entry,
      each next call takes the following entry while its level still matches, so
      two moves at one level come one after the other). With a free slot, "<MON>
      learned <MOVE>!" and its fanfare, A. With four moves known, "<MON> wants
      to learn the move <MOVE>. However, <MON> already knows four moves. Should
      a move be deleted and replaced with <MOVE>?" and the party's YES/NO box.
      YES: "Which move should be forgotten?", A, the summary's moves page as a
      list to forget from (the move offered on its fifth row), a move chosen
      with A, back to the party: "1, 2, and... Poof! <MON> forgot how to use
      <OLD>. And..." then "<MON> learned <MOVE>!". NO (or B): "Stop trying to
      teach <MOVE>?" and the same box; YES: "<MON> did not learn the move
      <MOVE>." and on to the next move; NO asks to delete again. A list left
      with B asks "Stop trying to teach?" too. A move the member knows already
      is skipped without a word.
    + Only once no move is left, the evolution ([PartyMenuTryEvolution]): when
      the member evolves at this level, the party menu closes (no further
      message) and the evolution scene starts, cancellable
      ([BeginEvolutionScene] with [canStopEvo] TRUE). "What? <MON> is
      evolving!", then the sprites cycle; B held alone
      ([gMain.heldKeys == B_BUTTON]) while they cycle stops it: "Huh? <MON>
      stopped evolving!", and no move is learned. Else "Congratulations! Your
      <MON> evolved into <NEW>!", then the new species' moves at this level,
      asked as in a battle ("<MON> is trying to learn <MOVE>." ... "Delete a
      move to make room for <MOVE>?", the battle's YES/NO box; B there is NO).
      Evolving into a species past Mew without the National Pokédex cancels
      itself.
    + The scene, or the party menu when nothing evolved, ends back in the bag
      ([CB2_ReturnToBagMenu], also the evolution's [gCB2_AfterEvolution]), the
      cursor still on the candy.

    Where it differs from the C++, which only ever declines and cancels: prompts
    and evolutions follow the plan ({!Level_up}); and it starts and ends on the
    overworld, one candy a call, where the C++ stays in the bag between candies
    and reads the stats for its RNG search. *)

type opened =
  | Opened  (** the candy given to the member *)
  | No_candy  (** no Rare Candy in the bag: the bag is closed again *)
  | Not_opened of string  (** why *)

type game_steps = {
  open_candy : slot:int -> (opened, Checkpoints.Failure.cause) result;
      (** From the overworld: the bag, the Rare Candy, USE, the slot (from 1).
          [Error] when a menu step after the candy's USE fails, as its cause. *)
  level_up : Level_up.game_steps;
      (** The party menu's: {!Level_up.Back} is the bag. *)
  close_bag : unit -> (unit, Checkpoints.Failure.cause) result;
      (** From the bag, back to the overworld; [Error] as {!open_candy}. *)
  log : string -> unit;
}
(** The steps in the game this module can take: what it reads and does on this
    context's screens (the overworld, the bag and the party menu). *)

type result =
  | Used of Level_up.outcome
      (** [levels] is 0 when the candy had no effect (a Lv 100 member) *)
  | Out_of_candies
  | Failed of string
  | Stopped of Checkpoints.Failure.cause
      (** a menu step of the game steps failed, as this cause *)

val run :
  game_steps -> Level_up_policy.policy -> member:Level_up.member -> result
(** One candy on the member: {!Level_up.run} with it alone. *)

val describe : result -> string
(** One line for the log. *)
