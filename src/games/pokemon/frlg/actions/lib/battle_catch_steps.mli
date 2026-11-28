(** FireRed/LeafGreen battle adapter for {!Pokemon_catch.Catch_runner}.

    GamePilot's own module (not in the fork): implements
    {!Pokemon_catch.Catch_runner.game_steps} over
    {!Frlg_battle.Battle.game_steps} and {!Frlg_readers.Battle_hud}, and
    provides ready-made {!phase1_policy} (2-Pokémon Spore Parasect + False Swipe
    Farfetch'd/Scyther) and {!phase2_policy} (single-slot Lv 100 Parasect)
    builders.

    Safety invariant: this adapter never calls
    {!Frlg_battle.Battle.game_steps}'s [run] field, answers YES to wild
    ["Use next POKéMON?"] prompts so it never flees after a faint, and pauses
    safely on level-up, move-learn, evolution, or timeout events. *)

type bag_layout = {
  ball_row : int;
      (** 0-based row of the target Poké Ball from the top of the Poké Balls
          pocket. *)
  heal_row : int;
      (** 0-based row of the healing item from the top of the Items pocket. *)
}
(** Bag row offsets used when throwing a ball or healing in battle. *)

type config = {
  initial_active_slot : int;
      (** 1-based party slot sent out at the start of the battle. *)
  bag : bag_layout;  (** Bag pocket row offsets. *)
  event_timeout_ms : int;
      (** Maximum time in ms to wait for the next FRLG battle event. *)
}
(** Configuration for {!make}. *)

type phase1_slots = {
  sleeper_slot : int;
      (** 1-based party slot of the Spore user (default 1: Parasect). *)
  spore_move : int;  (** 1-based move slot of Spore. *)
  swiper_slot : int;
      (** 1-based party slot of the False Swipe user (default 2:
          Farfetch'd/Scyther). *)
  false_swipe_move : int;  (** 1-based move slot of False Swipe. *)
  use_sleeper_as_wall : bool;
      (** When [true], retreat from the False Swiper back to [sleeper_slot] to
          absorb hits while throwing balls. *)
  send_in_order : int list;
      (** Ordered 1-based party slots to send in on a forced switch after a
          faint. *)
}
(** Party slot mapping for {!phase1_policy} (2-Pokémon catcher pair). *)

type phase2_slots = {
  catcher_slot : int;
      (** 1-based party slot of the single-slot Parasect (default 1). *)
  spore_move : int;  (** 1-based move slot of Spore. *)
  false_swipe_move : int;  (** 1-based move slot of False Swipe. *)
  send_in_order : int list;
      (** Ordered 1-based party slots to send in on a forced switch after a
          faint. *)
}
(** Party slot mapping for {!phase2_policy} (single-slot Lv 100 Parasect). *)

val default_event_timeout_ms : int
(** Default timeout in ms when waiting for the next battle event (30000 ms). *)

val default_phase1_slots : phase1_slots
(** Default Phase 1 layout: Slot 1 Spore (move 1) Parasect, Slot 2 False Swipe
    (move 1) Farfetch'd/Scyther, sleeper used as wall, send-in order
    [[1; 2; 3; 4; 5]]. *)

val default_phase2_slots : phase2_slots
(** Default Phase 2 layout: Slot 1 Parasect with Spore (move 1) and False Swipe
    (move 2), send-in order [[1; 2; 3; 4]]. *)

val make :
  ?battle:Frlg_battle.Battle.game_steps ->
  ?log:(string -> unit) ->
  config ->
  Pokemon_catch.Catch_runner.game_steps
(** Build FRLG {!Pokemon_catch.Catch_runner.game_steps}. Defaults [battle] to
    {!Frlg_battle.Battle_steps.make}. *)

val phase1_policy :
  ?ball_name:string ->
  ?max_balls:int ->
  ?max_turns:int ->
  phase1_slots ->
  Pokemon_catch.Catch_state.policy
(** Catch policy for the Phase 1 2-Pokémon catcher pair (Spore first, False
    Swipe while asleep, optional sleeper wall, re-apply Spore on wake). *)

val phase2_policy :
  ?ball_name:string ->
  ?max_balls:int ->
  ?max_turns:int ->
  phase2_slots ->
  Pokemon_catch.Catch_state.policy
(** Catch policy for the Phase 2 single-slot Lv 100 Parasect (Spore and False
    Swipe on the same slot with zero voluntary switches). *)
