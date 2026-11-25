(** Everything that comes after "a member levelled", for every member that did:
    each level's stats window, the moves each level offers answered by the
    member's {!Level_up_policy.policy}, each evolution let run or cancelled, and
    the evolved species' own moves; until the screen is back where the context
    ends. The context comes as a {!driver}: its screens
    ({!Level_up_screens.context}), how its text is pressed through, and what
    "back" means (the bag after a Rare Candy, the overworld after a battle).
    Only the party menu's driver is built ({!Rare_candy_steps}); a battle's is
    the follow-up. A Rare Candy is the one-member case.

    Text and language: [Level_up] never matches text. The quoted strings below
    are the English messages, there so a reader can find each step in the game;
    other languages word them differently and at other lengths. A driver tells
    the screens apart by their layout (the text box and its arrow, the YES/NO
    box, the stats window, the list to forget from), which is the same in every
    language. The one text a driver may read is the member's name in "<MON>
    gained <N> EXP. Points!" and "<MON> is evolving!", and that read is
    language-dependent. The name shown there is the member's nickname, not its
    species (seen on mGBA 2026-11-24: CH'DING, MIMIEN), hence {!Nickname}.

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

    Who a screen is about: the driver names the member where it reads the text
    ({!who}); else the order tells. A stats window belongs to the member of the
    last {!Exp} message (the first member before any), the next {!Exp} to the
    next member in slot order (wrapping round at the next foe's faint). A scene
    belongs to the next member, in slot order after the last scene's, that
    levelled; with names unread, a levelled member whose species does not evolve
    would shift the scenes after it onto the wrong member, so the battle driver
    must read them. Move prompts belong to the member of the stats window or
    scene they follow. *)

(** A member as the driver knows it: its party slot (from 1) where the context
    knows it (the party menu's highlight), or the nickname read off the text. A
    nickname is found among the [members] given to {!run}; when two of them
    share it, it does not tell them apart, so the order decides (as with no
    name) and the log says so. *)
type who = Slot of int | Nickname of string

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
  | Timed_out  (** none of these within the driver's bound *)

type forget_list = {
  offered : string option;  (** the fifth row: the move offered *)
  known : string option list;  (** rows 0-3 *)
}

(** How an evolution scene left off. *)
type scene = Continues  (** a question or a page of it shows *) | Ended

type driver = {
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
  log : string -> unit;  (** Where {!run} logs each answer. *)
}
(** The callbacks a context supplies so {!run} can answer its screens: how to
    press through its text to the next {!look}, read its screens, and answer its
    YES/NO boxes. {!run} decides; the driver only presses and reads. The Rare
    Candy action builds one for the party menu; a battle will build its own. *)

type member = {
  slot : int;  (** party slot, from 1 *)
  species : string;  (** a slug; picks the member's policy *)
  nickname : string option;
      (** the name the game's text shows, when the context knows it *)
}
(** A member that may level. *)

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
  driver ->
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
