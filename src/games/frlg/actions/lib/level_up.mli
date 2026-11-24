(** Everything that comes after "a member levelled", for every member that did:
    each level's stats window, the moves each level offers answered by the
    member's {!Level_up_policy.policy}, each evolution let run or cancelled, and
    the evolved species' own moves; until the screen is back where the context
    ends. The context comes as a {!rig}: its screens
    ({!Level_up_screens.context}), how its text is pressed through, and what
    "back" means (the bag after a Rare Candy, the overworld after a battle).
    Only the party menu's rig is built ({!Rare_candy_steps}); a battle's is the
    follow-up. A Rare Candy is the one-member case.

    The order the game shows them in (pokefirered):
    + In a battle, at each foe's faint, the EXP step (battle_script_commands.c,
      [Cmd_getexp]) goes through the party in slot order (1 to 6), skipping
      members that did not take part and hold no Exp. Share, and those at Lv
      100: "<MON> gained <N> EXP. Points!", then the EXP one level at a time
      ([getexpState] 3 to 5, looping while EXP is left). Each level: "<MON> grew
      to Lv. <L>!", its stats window (two pages), then that level's moves
      ([BattleScript_LevelUp], [handlelearnnewmove]: in learnset order, a free
      slot learned at once, with four known "<MON> is trying to learn ... Delete
      a move to make room for ...?", the battle's YES/NO; NO asks "Stop learning
      ...?"). Then the next level, then the next member.
    + After a won battle, the evolutions ([TryEvolvePokemon], battle_main.c):
      each member that levelled ([gLeveledUpInBattle]), in slot order, whose
      species evolves at its level, gets its own scene ([EvolutionScene] with
      [canStopEvo] set: B held alone while the sprites cycle stops it). A scene
      that ran asks for the evolved species' moves at that level, battle-style
      (evolution_scene.c, [EVOSTATE_TRY_LEARN_MOVE]); a stopped one asks
      nothing. Then the next member's scene, then the overworld.
    + A Rare Candy (party_menu.c): one level, its stats window and moves, then
      at once its evolution, back to the bag ({!Rare_candy}).

    Who a screen is about: the rig names the member where it reads the text
    ({!who}); else the order tells. A stats window belongs to the member of the
    last {!Exp} message (the first member before any), the next {!Exp} to the
    next member in slot order (wrapping round at the next foe's faint). A scene
    belongs to the next member, in slot order after the last scene's, that
    levelled; with names unread, a levelled member whose species does not evolve
    would shift the scenes after it onto the wrong member, so the battle rig
    must read them. Move prompts belong to the member of the stats window or
    scene they follow. *)

(** A member as the rig read it off the text. *)
type who = Slot of int | Species of string

(** What the screen asks for next. *)
type look =
  | Exp of who option
      (** "<MON> gained <N> EXP. Points!": the next levels are this member's *)
  | Stats of who option  (** a level's stats window, pressed through *)
  | Move_prompt  (** a YES/NO: a move to delete for the one offered *)
  | Forget_list
      (** the list to forget from, though no YES was given (an A meant for the
          text before took it) *)
  | Evolving of who option  (** an evolution scene, no question on it *)
  | Back  (** where the context ends: the bag, the overworld *)
  | Timed_out  (** none of these within the rig's bound *)

type forget_list = {
  offered : string option;  (** the fifth row: the move offered *)
  known : string option list;  (** rows 0-3 *)
}

(** How an evolution scene left off. *)
type scene = Continues  (** a question or a page of it shows *) | Ended

type rig = {
  next : unit -> look;
      (** Presses through text and stats windows (never B) until a {!look}. *)
  open_list : unit -> bool;
      (** On a {!Move_prompt}: YES and on until the list to forget from shows.
      *)
  read_list : unit -> forget_list;
  forget : int -> bool;
      (** On the list: move [i] (0-3) chosen, the list gone. False when its
          cursor did not read there. *)
  leave_list : unit -> bool;
      (** On the list: B off it, then YES to stop teaching. *)
  decline : unit -> bool;
      (** On a {!Move_prompt}: NO, then YES to stop teaching. *)
  evolution : cancel:bool -> scene;
      (** On {!Evolving}: B held if [cancel], else nothing pressed, until the
          scene shows something else. *)
  log : string -> unit;
}

type member = { slot : int; species : string }
(** A member that may level: its party slot (from 1) and species. *)

type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  member : member;
  levels : int;  (** stats windows shown: the levels gained *)
  learned : Level_up_policy.move_rule list;  (** in order *)
  declined : string option list;  (** the moves declined, when read *)
  evolution : evolution;
}

val max_looks : int
(** {!look}s before it fails: 200 per run (six members, several levels each). *)

val run :
  rig ->
  Level_up_policy.t ->
  members:member list ->
  (outcome list, string) result
(** Until {!Back}; one outcome per member, in [members]' order, which must be
    the party's. [Error] with why: nothing showed, a question did not come, the
    list did not show or its cursor did not read, a screen with no member to
    belong to, too many looks. Logs each answer. *)

val evolution_name : evolution -> string
(** ["none"], ["evolved"], ["cancelled"]. *)

val describe : outcome -> string
(** ["1 level; learned mean-look; declined none; evolution none"]. *)
