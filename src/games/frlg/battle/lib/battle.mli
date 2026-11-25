(** A battle's game steps: the verbs it is played with, as a record of functions
    ({!game_steps}), so the {!Scripted_battle} runner runs on any:
    {!Battle_steps} presses FireRed's buttons and reads its screen, a test
    answers from a list.

    Slots count from 0. Move slots as the move menu shows them: 0 top left, 1
    top right, 2 bottom left, 3 bottom right. Party slots as the party list
    shows them in battle, which is battle order: the members out first, so a
    switch changes which member a slot holds. *)

(** Where a move goes. A target cursor only shows in a double battle, for a move
    that hits one battler, while more than one other battler stands. *)
type target =
  | Default
      (** No cursor expected: a single battle, a move that hits a side or the
          user. Should a cursor show anyway, A takes its start, the foe on the
          left. *)
  | Ally  (** the partner *)
  | Foe_left
  | Foe_right

(** What the battle asks for next. *)
type event =
  | Action_menu
      (** FIGHT / BAG / POKEMON / RUN for the next battler: one command is due.
          A double battle asks twice a turn. *)
  | Switch_in
      (** The game opened the party list itself: a battler fainted and a member
          must be sent in. *)
  | Move_learn
      (** A YES/NO with the player's battler out: "Delete a move to make room
          for ...?", or after NO, "Stop learning ...?". *)
  | Use_next
      (** A YES/NO with the player's battler gone: "Use next POKéMON?" in a wild
          battle. *)
  | Battle_over  (** no battle on screen for a while after one showed *)
  | Timed_out  (** none of these within the time given *)

(** What came of a move chosen. *)
type move_result =
  | Chosen
  | Refused
      (** The game turned it down (no PP left, Disable) and the action menu is
          back. *)
  | Other_move of string
      (** The slot holds this move, not the one the script names; the steps went
          back to the action menu without choosing. *)
  | Not_done of string  (** the steps could not make the choice: why *)

type item = {
  pocket : Frlg_readers.Bag_screen.pocket;
  row : int;  (** from 0 at the top of the pocket *)
  on_slot : int option;  (** the party slot it is used on, if it asks for one *)
}
(** A bag item used from the action menu. *)

(** The answer to "Delete a move to make room for ...?". *)
type learn =
  | Keep_moves  (** NO, then YES to "Stop learning ...?" *)
  | Forget of int  (** YES, and this move (0-3) forgotten whatever is offered *)
  | Forget_for of { move : string; slot : int }
      (** YES; [slot] (0-3) forgotten only when the move offered, read on the
          list to forget from (its fifth row), is [move] (a slug). Any other
          move is backed out of and not learned. *)

(** What came of a {!learn} answer. *)
type learned =
  | Learned of { slot : int; move : string option }
      (** [slot] forgotten for the new move, [move] when it was read *)
  | Not_learned of { offered : string option }
      (** the moves kept; [offered] when it was read *)
  | Unread of string
      (** the move offered did not read, or the list's cursor did not: backed
          out with NO to "Stop learning ...?", so the game asks again *)

type game_steps = {
  next_event : timeout_ms:int -> event;
      (** Plays the battle on (text, level-up boxes) until it asks for
          something, ends, or [timeout_ms] passes. *)
  use_move : slot:int -> target:target -> expect:string option -> move_result;
      (** From the action menu: FIGHT, the move in [slot], its target. With
          [expect], the move's name is checked first where the steps can read
          it. *)
  switch_to : slot:int -> bool;
      (** From the action menu: POKEMON and SHIFT to [slot]. False, back at the
          action menu, if the game refused (the member out already, fainted). *)
  send_in : slot:int -> bool;
      (** On {!Switch_in}'s party list: SHIFT to [slot]. False if the list
          stayed open. *)
  run : unit -> unit;
      (** From the action menu: RUN. Whether it worked shows in the next event:
          {!Battle_over}, or the action menu again. *)
  use_item : item -> bool;
      (** From the action menu: BAG, the item, its target. False if the bag did
          not show the pocket or did not close. *)
  answer_move_learn : learn -> learned;
      (** On {!Move_learn}, the whole exchange: "Delete a move ...?", the list
          to forget from, and "Stop learning ...?" when the move is not taken
          (pokefirered battle_script_commands.c: YES there stops, NO or B asks
          again). *)
  answer_use_next : bool -> unit;  (** On {!Use_next}: YES or NO. *)
}

val target_name : target -> string
val describe_learned : learned -> string
val event_name : event -> string
