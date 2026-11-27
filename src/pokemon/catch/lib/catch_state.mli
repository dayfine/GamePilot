(** Game-agnostic state, policy, and command types for automated Pokémon
    legendary catching.

    The command type intentionally omits a [Run] constructor so a catch policy
    can never flee from a target encounter. *)

type t = {
  turn : int;  (** Number of action menus answered so far in this battle. *)
  active_slot : int;  (** 1-based party slot currently on the field. *)
  active_hp_ratio : float;
      (** Active party member's remaining HP fraction in [0.0 .. 1.0]. *)
  foe_hp_ratio : float;
      (** Wild foe's remaining HP fraction in [0.0 .. 1.0]. *)
  foe_asleep : bool;  (** [true] when the wild foe currently has Sleep. *)
  balls_thrown : int;  (** Number of Poké Balls thrown so far in this battle. *)
}
(** Observed battle state at an action menu. *)

type role_config = {
  slot : int;  (** 1-based party slot fulfilling this role. *)
  move_slot : int;  (** 1-based move slot to use for this role. *)
  hp_floor : float;
      (** Minimum HP ratio before switching to the wall for survival. *)
}
(** Configuration for a single-move support role such as a sleeper. *)

type false_swipe_config = {
  slot : int;  (** 1-based party slot of the False Swipe user. *)
  move_slot : int;  (** 1-based move slot of False Swipe. *)
  require_sleep : bool;
      (** When [true], put the foe to sleep before sending in the False Swiper
          and switch to the wall before throwing balls. *)
  hp_floor : float;  (** Minimum HP ratio before retreating to the wall. *)
}
(** Configuration for the HP-chipping False Swipe role. *)

type wall_config = {
  slot : int;  (** 1-based party slot of the defensive wall. *)
  heal_move_slot : int option;
      (** Optional 1-based move slot of a self-healing move (e.g. Recover). When
          [None], survival falls back to {!Heal_active}. *)
  hp_floor : float;  (** Minimum HP ratio before the wall heals itself. *)
}
(** Configuration for the defensive wall that absorbs hits while throwing balls.
*)

type policy = {
  sleeper : role_config option;
      (** Optional party member that applies Sleep. *)
  false_swiper : false_swipe_config option;
      (** Optional party member that chips the foe's HP with False Swipe. *)
  wall : wall_config;
      (** Defensive party member that absorbs damage during ball throws. *)
  ball_name : string;  (** Name of the Poké Ball to throw. *)
  max_balls : int;  (** Pause for user once this many balls have been thrown. *)
  foe_hp_target : float;
      (** Initial foe HP ratio threshold above which chipping runs. *)
  foe_hp_rechip : float;
      (** Higher foe HP ratio threshold used after balls have been thrown, to
          re-chip foes that heal (e.g. Aqua Ring or Rest). *)
  reapply_sleep : bool;
      (** When [true], re-apply Sleep whenever the foe wakes up. *)
  max_turns : int;
      (** Pause for user once this many turns have elapsed, preventing Struggle
          or unbounded loops. *)
  send_in_order : int list;
      (** Ordered 1-based party slots to send in on a forced switch after a
          faint. *)
}
(** Complete catching strategy for a target encounter. *)

(** Action chosen at a battle action menu. Intentionally has no [Run] case. *)
type command =
  | Use_move of int  (** Use the 1-based move slot of the active member. *)
  | Switch_to of int  (** Switch to the 1-based party slot. *)
  | Throw_ball of string  (** Throw the named Poké Ball from the Bag. *)
  | Heal_active  (** Use a healing item on the active party member. *)
  | Pause_for_user of string
      (** Stop automation safely and hand control back to the player. *)

val describe_command : command -> string
(** Short human-readable description of a {!command} for logs. *)
