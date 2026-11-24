(** The ["use_rare_candy"] game action's decisions: one Rare Candy from the bag
    on a party member, the moves it offers answered by the plan's rules
    ({!Candy_plan}), its evolution let run or cancelled, back to the overworld.
    Ported from upstream's [use_rare_candy()]
    (Programs/RngManipulation/PokemonFRLG_RngNavigation.cpp): the bag, A on the
    candy until the party shows, the slot, A until the level-up stats show, then
    until the bag is back, answering each move-learn prompt (B, A: NO, then YES
    to stop) and each evolution (B) on the way. The game's steps come as a
    {!rig}, so the decisions run on a fake in tests; {!Rare_candy_steps} is the
    game's.

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

    Where it differs from the C++, which only ever declines and cancels:
    - Prompts are answered by the plan: a rule that names the move offered, read
      on the list to forget from, forgets the rule's move there; any other move
      is declined. With no rules the prompt is declined at once, NO then YES, as
      the C++ presses B then A.
    - An evolution is let run when the plan allows it, pressing nothing; to
      cancel it, B is held through the scene's start, not tapped every 2 s.
    - It starts and ends on the overworld, one candy a call; the C++ stays in
      the bag between candies and reads the stats for its RNG search. *)

(** What the screen asks for after the candy is given. *)
type look =
  | Level_up  (** the stats window: the candy took *)
  | Move_prompt
      (** a YES/NO box over the party or the evolution scene: a move to delete
          for the one offered *)
  | Forget_list
      (** the list to forget from, though the action never said YES (an A meant
          for the text before took it) *)
  | Evolving  (** the evolution scene, no question on it *)
  | In_bag  (** back in the bag *)
  | Timed_out  (** none of these within the rig's bound *)

type forget_list = {
  offered : string option;  (** the fifth row: the move offered *)
  known : string option list;  (** rows 0-3 *)
}

type opened =
  | Opened  (** the candy given to the member *)
  | No_candy  (** no Rare Candy in the bag: the bag is closed again *)
  | Not_opened of string  (** why *)

type rig = {
  open_candy : slot:int -> opened;
      (** From the overworld: the bag, the Rare Candy, USE, the slot (from 1).
      *)
  next : unit -> look;  (** Presses through text (never B) until a {!look}. *)
  open_list : unit -> bool;
      (** On a {!Move_prompt}: YES and on until the list to forget from shows.
          False when it did not. *)
  read_list : unit -> forget_list;
  forget : int -> bool;
      (** On the list: move [i] (0-3) chosen. False when its cursor did not read
          there (the list left, the move not learned). *)
  leave_list : unit -> bool;
      (** On the list: B off it, then YES to stop teaching. False when the
          question did not come. *)
  decline : unit -> bool;
      (** On a {!Move_prompt}: NO, then YES to stop teaching. False when the
          second question did not come. *)
  evolution : cancel:bool -> unit;
      (** On {!Evolving}: until the scene shows something else, B held if
          [cancel], else pressing nothing. *)
  close_bag : unit -> unit;  (** From the bag, back to the overworld. *)
  log : string -> unit;
}

type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  levelled : bool;  (** the stats window showed *)
  learned : Candy_plan.move_rule list;  (** in order *)
  declined : string option list;  (** the moves declined, when read *)
  evolution : evolution;
}

type result = Used of outcome | Out_of_candies | Failed of string

val max_looks : int
(** {!look}s one candy may take before it fails: 40. *)

val run : rig -> Candy_plan.use -> slot:int -> result
(** One candy on the member in [slot]. Logs each answer. *)

val evolution_name : evolution -> string
(** ["none"], ["evolved"], ["cancelled"]. *)

val describe : result -> string
(** One line for the log. *)
