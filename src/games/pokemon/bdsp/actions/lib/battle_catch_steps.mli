(** BDSP battle adapter for {!Pokemon_catch.Catch_runner}.

    GamePilot's own module (not in the fork): implements
    {!Pokemon_catch.Catch_runner.game_steps} over {!Effects} using
    {!Bdsp_readers.Battle_hud}, {!Bdsp_readers.Battle_detector},
    {!Bdsp_readers.Dialog_detector}, and {!Switch.Black_screen}, and provides
    ready-made {!kyogre_policy} and {!groudon_policy} builders.

    Safety invariant: this adapter never selects the Run button (row 3 of the
    BDSP battle menu) and pauses cleanly on any timeout or unrecognized
    transition. *)

type bag_layout = {
  ball_pocket_steps : int;
      (** Horizontal pocket taps from the initial Bag pocket to the Poké Balls
          pocket (positive = Right, negative = Left). *)
  ball_row : int;  (** 0-based row of the target Poké Ball in its pocket. *)
  heal_pocket_steps : int;
      (** Horizontal pocket taps from the initial Bag pocket to the Medicine
          pocket (positive = Right, negative = Left). *)
  heal_row : int;  (** 0-based row of the healing item in its pocket. *)
}
(** Bag navigation offsets for throwing balls and healing in battle. *)

type timing = {
  press_hold_ms : int;  (** Hold duration for confirm/menu taps in ms. *)
  press_cooldown_ms : int;  (** Cooldown after confirm taps in ms. *)
  nav_cooldown_ms : int;  (** Cooldown between D-pad cursor steps in ms. *)
  menu_settle_ms : int;  (** Settle wait after opening Fight/Pokémon/Bag. *)
  event_timeout_ms : int;  (** Max wait for the next battle event in ms. *)
  dialog_advance_ms : int;  (** Cooldown after advancing a battle dialog. *)
  black_hold_ms : float;
      (** Minimum black-screen duration to count as battle fade-out. *)
}
(** Button press and wait timings for BDSP battle navigation. *)

type config = {
  picture : Wire.box;  (** Game picture viewport from the daemon's [hello]. *)
  initial_active_slot : int;
      (** 1-based party slot sent out at the start of the battle. *)
  bag : bag_layout;  (** Bag pocket and item row offsets. *)
  timing : timing;  (** Press and wait timings. *)
}
(** Configuration for {!make}. *)

type party_slots = {
  status_setter : int;  (** 1-based party slot of the status move user. *)
  status_move : int;  (** 1-based move slot of the status move. *)
  false_swiper : int;  (** 1-based party slot of the False Swipe user. *)
  false_swipe_move : int;  (** 1-based move slot of False Swipe. *)
  wall : int;  (** 1-based party slot of the defensive wall. *)
  wall_heal_move : int option;
      (** Optional 1-based move slot of the wall's recovery move. *)
  send_in_order : int list;
      (** Ordered 1-based party slots to send in after a faint. *)
}
(** Party slot mapping shared by {!kyogre_policy} and {!groudon_policy}. *)

val default_timing : timing
(** Conservative default timings for BDSP battle menus on Switch. *)

val make :
  ?log:(string -> unit) -> config -> Pokemon_catch.Catch_runner.game_steps
(** Build BDSP {!Pokemon_catch.Catch_runner.game_steps} driven through
    {!Effects}. *)

val kyogre_policy :
  ?ball_name:string ->
  ?max_balls:int ->
  ?max_turns:int ->
  party_slots ->
  Pokemon_catch.Catch_state.policy
(** Catch policy tuned for Ramanas Park Kyogre (sleep-first, fragile False
    Swiper, Aqua Ring re-chip threshold, Luxury Ball default). *)

val groudon_policy :
  ?ball_name:string ->
  ?max_balls:int ->
  ?max_turns:int ->
  party_slots ->
  Pokemon_catch.Catch_state.policy
(** Catch policy tuned for Ramanas Park Groudon (sleep-first, fragile False
    Swiper, Rest re-chip threshold, Luxury Ball default). *)
