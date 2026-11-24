(** Everything that comes after "the member levelled", wherever it levelled:
    each level's stats window, the moves each level offers answered by the
    plan's {!move_rule}s, the evolution let run or cancelled, and the new
    species' own moves; until the screen is back where the context ends. The
    context comes as a {!rig}: which YES/NO box and stats window it shows, how
    its text is pressed through, and what "back" means (the bag after a Rare
    Candy, the battle or the overworld after a battle). Only the party menu's
    rig is built ({!Rare_candy_steps}); a battle's is the follow-up.

    What the game shows, in order (pokefirered; a Rare Candy's in
    {!Rare_candy}): per level, the stats window, then each move of that level in
    learnset order (two at one level one after the other), asked only when four
    moves are known: "Should a move be deleted and replaced with ...?" (the
    party) or "Delete a move to make room for ...?" (a battle, the evolution
    scene). YES opens the summary's moves page as a list to forget from, the
    move offered on its fifth row; NO (or B) asks "Stop trying to teach / Stop
    learning ...?", where YES declines. A battle that gives several levels shows
    each level's window and moves in turn, and its evolutions only after it
    ends, and only if won (battle_main.c, [TryEvolvePokemon] over
    [gLeveledUpInBattle], set at each level-up of the EXP step in
    battle_script_commands.c); a candy's comes after its moves (party_menu.c,
    [PartyMenuTryEvolution]). The evolution scene stops when B alone is held
    while the sprites cycle (evolution_scene.c); otherwise the evolved species
    asks for its own moves at the level, battle-style. One member's level-ups at
    a time. *)

type move_rule = {
  learn : string;  (** the move offered, a slug *)
  replacing : string;  (** the known move it is learned over, a slug *)
}

type policy = {
  rules : move_rule list;
      (** in the plan's order; the first that learns the move offered is taken,
          any move no rule names is declined *)
  evolve : bool;  (** let an evolution run; else cancel it with B *)
}

val rule_for : move_rule list -> offered:string -> move_rule option

val describe_rule : move_rule -> string
(** ["mean-look over lick"]. *)

(** What the screen asks for next. *)
type look =
  | Stats  (** a level's stats window, pressed through by the rig *)
  | Move_prompt  (** a YES/NO: a move to delete for the one offered *)
  | Forget_list
      (** the list to forget from, though no YES was given (an A meant for the
          text before took it) *)
  | Evolving  (** the evolution scene, no question on it *)
  | Back  (** where the context ends: the bag, the battle, the overworld *)
  | Timed_out  (** none of these within the rig's bound *)

type forget_list = {
  offered : string option;  (** the fifth row: the move offered *)
  known : string option list;  (** rows 0-3 *)
}

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
  evolution : cancel:bool -> unit;
      (** On {!Evolving}: until the scene shows something else, B held if
          [cancel], else pressing nothing. *)
  log : string -> unit;
}

type evolution = No_evolution | Evolved | Cancelled

type outcome = {
  levels : int;  (** stats windows shown: the levels gained *)
  learned : move_rule list;  (** in order *)
  declined : string option list;  (** the moves declined, when read *)
  evolution : evolution;
}

val max_looks : int
(** {!look}s before it fails: 40 per run. *)

val run : rig -> policy -> (outcome, string) result
(** Until {!Back}. [Error] with why: nothing showed, a question did not come,
    the list did not show or its cursor did not read, too many looks. Logs each
    answer. *)

val evolution_name : evolution -> string
(** ["none"], ["evolved"], ["cancelled"]. *)

val describe : outcome -> string
(** ["1 level; learned mean-look; declined none; evolution none"]. *)
