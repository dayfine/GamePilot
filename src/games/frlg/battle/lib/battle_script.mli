(** A battle written down as data: the commands for the first action menus in
    order, what to do at the action menus after them, whom to send in when a
    member faints, and the answers to the prompts. {!Scripted_battle} plays it
    on a {!Battle_driver}.

    One command per action menu: a single battle asks once a turn, a double
    battle twice (its left battler first). The Mail Glitch's three battles:

    - switch-grind (mg-04): [opening = [Switch 1]], [fallback = Attack] with the
      sweeper's moves, [send_ins = [{ slot = 1; then_ = None }]] in case the
      trainee faints before the switch, [forget = Some learn_slot]; a second
      faint, the sweeper's, finds no send-in left and fails the battle;
    - faint-and-flee (mg-05's Berry holder): [fallback = Attack] with move 0,
      [send_ins = [{ slot = 1; then_ = Some Flee }]];
    - the double battle (mg-05): four opening commands (Knock Off on the ally, a
      switch, a switch, Recycle), then [Attack] with Surf, [Default] as it hits
      both foes. *)

type command =
  | Move of {
      slot : int;
      target : Battle_driver.target;
      name : string option;
          (** the move the slot must hold, checked where the driver can read it
          *)
    }
  | Switch of int  (** party slot *)
  | Item of Battle_driver.item
  | Run

(** What each action menu after the opening gets. *)
type fallback =
  | Attack of { slots : int list; target : Battle_driver.target }
      (** the first of [slots] the game has not refused in this battle (no PP
          left), so a list rotates as each runs dry *)
  | Flee  (** RUN, again after a failed escape *)
  | Stop  (** nothing: an action menu after the opening fails the battle *)

type send_in = {
  slot : int;  (** the party slot sent in *)
  then_ : fallback option;  (** the fallback from then on; [None] keeps it *)
}
(** The answer to one forced switch-in, in the order they come. A switch-in also
    drops what is left of the opening: it was written for the battle as it
    started, and the member it planned for has fallen. *)

type t = {
  opening : command list;
  fallback : fallback;
  send_ins : send_in list;
      (** A switch-in past these fails the battle: a member fell that the script
          did not plan for. *)
  forget : int option;
      (** "Delete a move?": the move slot to forget for the new move, or [None]
          to keep the moves. *)
  use_next : bool;  (** "Use next POKéMON?" *)
  max_menus : int;  (** more action menus than this fail the battle *)
  event_timeout_ms : int;  (** the longest wait for the battle's next event *)
}

val default_max_menus : int
(** 40: well past any Mail Glitch battle (the fork's loops allow 12 to 25
    turns), short of a battle that has gone wrong (a RUN refused for ever). *)

val default_event_timeout_ms : int
(** 60 s, the fork's BATTLE_MENU_TIMEOUT: the longest a turn's text and
    animations take. *)

val make :
  ?opening:command list ->
  ?send_ins:send_in list ->
  ?forget:int ->
  ?use_next:bool ->
  ?max_menus:int ->
  ?event_timeout_ms:int ->
  fallback ->
  t
(** No opening, no send-ins, the moves kept, NO to "Use next POKéMON?", and the
    defaults above. *)

val describe_command : command -> string
(** ["move 2 (ally)"], ["switch to 3"], ["item row 0"], ["run"]. *)
