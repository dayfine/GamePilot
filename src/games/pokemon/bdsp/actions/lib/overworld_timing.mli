(** Timing constants for BDSP overworld movement, doorway fades, X-menu
    navigation, dialogs, wild battle escapes, and Bag inspection. *)

type action_t = {
  hold_ms : int;  (** Standard button press hold duration in ms. *)
  cooldown_ms : int;  (** Standard button press release cooldown in ms. *)
  radar_cooldown_ms : int;  (** Cooldown after pulsing the [R] radar in ms. *)
}
(** Overworld action press timings. *)

type door_t = {
  default_hold_ms : int;  (** Default walk duration into a Hideaway doorway. *)
  step_ms : int;  (** Single walk-step pulse duration toward a doorway. *)
  retry_hold_ms : int;  (** Walk duration after a perpendicular nudge. *)
  nudge_step_ms : int;  (** Sideways nudge duration when off-center. *)
  fade_timeout_ms : int;  (** Max wait for doorway fade transition. *)
  black_hold_ms : float;  (** Minimum black-screen hold duration in ms. *)
  clear_hold_ms : float;  (** Minimum non-black hold duration in ms. *)
}
(** Hideaway doorway crossing and fade timings. *)

type menu_t = {
  press_hold_ms : int;  (** Hold duration for menu open/close/confirm. *)
  press_cooldown_ms : int;  (** Cooldown after menu open/close/confirm. *)
  nav_hold_ms : int;  (** Hold duration for D-pad cursor steps. *)
  nav_cooldown_ms : int;  (** Cooldown between D-pad cursor steps. *)
  wait_timeout_ms : int;  (** Max wait for the X-menu to open or close. *)
  post_wait_ms : int;  (** Settle wait after detecting the open menu. *)
}
(** X-menu open, close, and cursor navigation timings. *)

type dialog_t = {
  max_presses : int;  (** Default max button presses to clear a dialog. *)
  press_cooldown_ms : int;  (** Cooldown between dialog advance/dismiss taps. *)
  frame_timeout_ms : int;  (** Max wait for a frame while polling dialogs. *)
  bag_open_wait_ms : int;  (** Settle wait after opening the Bag. *)
  kit_confirm_wait_ms : int;  (** Wait after confirming Explorer Kit prompts. *)
  dive_timeout_ms : int;  (** Max wait for Grand Underground dive fade. *)
  battle_timeout_ms : int;  (** Max wait for wild battle menu to appear. *)
  battle_run_wait_ms : int;  (** Settle wait after selecting Run in battle. *)
}
(** Dialog, Explorer Kit dive, and wild battle escape timings. *)

type bag_t = {
  scroll_pages : int;  (** Number of Treasures pocket pages to scroll. *)
  page_rows : int;  (** Rows per Treasures pocket page. *)
  nav_hold_ms : int;  (** Hold duration for Bag cursor taps. *)
  nav_cooldown_ms : int;  (** Cooldown between Bag cursor taps. *)
  page_wait_ms : int;  (** Dwell time on each Treasures pocket page. *)
  exit_presses : int;  (** Number of B presses to close the Bag. *)
  exit_cooldown_ms : int;  (** Cooldown between Bag exit B presses. *)
}
(** Bag Treasures pocket inspection timings. *)

val act : action_t
(** Default overworld action press timings. *)

val door : door_t
(** Default Hideaway doorway crossing and fade timings. *)

val menu : menu_t
(** Default X-menu timings. *)

val dlg : dialog_t
(** Default dialog, dive, and battle timings. *)

val bag : bag_t
(** Default Bag Treasures pocket inspection timings. *)
