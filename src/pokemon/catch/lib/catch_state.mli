(** Game-agnostic state, policy, and command types for automated Pokémon
    catching.

    The command type intentionally omits a [Run] constructor so a catch policy
    can never flee from a target encounter. *)

(** Observed major status condition on the wild foe. *)
type foe_status =
  | Healthy  (** No major status condition is visible on the foe HUD. *)
  | Asleep  (** Wild foe is currently asleep. *)
  | Paralyzed  (** Wild foe is currently paralyzed. *)
  | Other_status
      (** Wild foe has another major status (Burn, Poison, Freeze). *)

val is_statused : foe_status -> bool
(** [true] when the wild foe has any non-{!Healthy} major status condition. *)

type t = {
  turn : int;  (** Number of action menus answered so far in this battle. *)
  active_slot : int;  (** 1-based party slot currently on the field. *)
  active_hp_ratio : float option;
      (** Active party member's remaining HP fraction in [0.0 .. 1.0], or [None]
          when the HUD reader does not supply it (skips the survival check). *)
  foe_hp_ratio : float option;
      (** Wild foe's remaining HP fraction in [0.0 .. 1.0], or [None] when the
          HUD reader does not supply it (skips chipping). *)
  foe_status : foe_status option;
      (** Observed status of the wild foe, or [None] when the HUD reader does
          not supply it (skips status checks). *)
  balls_thrown : int;  (** Number of Poké Balls thrown so far in this battle. *)
  fainted : int list;
      (** 1-based party slots known to have fainted in this battle; the policy
          never switches to a slot listed here. *)
  setup_uses_done : int;
      (** Number of setup-move turns completed so far (e.g. Swords Dance). *)
  wall_move_heals_done : int;
      (** Number of times the wall's self-healing move (e.g. Synthesis, 5 PP)
          has been used so far; once exhausted, survival falls back to
          {!Heal_active}. *)
}
(** Observed battle state at an action menu. *)

type setup_config = {
  slot : int;  (** 1-based party slot that uses the setup move. *)
  move_slot : int;  (** 1-based move slot of the setup move (e.g. Swords Dance). *)
  uses : int;  (** Number of setup turns to execute before chipping. *)
  require_status : bool;
      (** When [true], apply status (e.g. Sleep) before setting up. *)
}
(** Configuration for an optional stat-boosting setup phase during the foe's
    first sleep (e.g. 2× Swords Dance before False Swiping). *)

type role_config = {
  slot : int;  (** 1-based party slot fulfilling this role. *)
  move_slot : int;  (** 1-based move slot to use for this role. *)
  hp_floor : float;
      (** Minimum HP ratio before switching to the wall (or healing) for
          survival. *)
}
(** Configuration for a single-move support role such as a status setter. *)

type heavy_chipper_config = {
  slot : int;  (** 1-based party slot of the bruiser/tank chipper. *)
  move_slot : int;  (** 1-based move slot of its safe neutral attack. *)
  hp_floor : float;
      (** Minimum HP ratio before retreating to the wall (or healing). *)
  foe_hp_floor : float;
      (** Stop heavy-chipping once the foe's HP ratio is at or below this floor
          (e.g. [0.30] for 30%) so a critical hit cannot KO the target. *)
  require_status : bool;
      (** When [true], apply a status condition before sending in the chipper.
      *)
}
(** Configuration for an optional bruiser/tank that winds a healthy foe down to
    [foe_hp_floor] before handing off to {!false_swipe_config}. *)

type false_swipe_config = {
  slot : int;  (** 1-based party slot of the False Swipe user. *)
  move_slot : int;  (** 1-based move slot of False Swipe. *)
  require_status : bool;
      (** When [true], apply a status condition before sending in the False
          Swiper and switch to a healthy wall before throwing balls. *)
  hp_floor : float;
      (** Minimum HP ratio before retreating to the wall (or healing). *)
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
  status_setter : role_config option;
      (** Optional party member that applies a status condition (e.g. Sleep
          Powder or Thunder Wave). *)
  setup : setup_config option;
      (** Optional stat-boosting setup phase (e.g. Swords Dance) executed during
          the foe's first sleep before chipping. *)
  heavy_chipper : heavy_chipper_config option;
      (** Optional bruiser/tank that winds the foe down to [foe_hp_floor] (e.g.
          20%–30%) before handing off to [false_swiper]. Only runs before the
          first ball is thrown. *)
  false_swiper : false_swipe_config option;
      (** Optional party member that chips the foe's HP with False Swipe. *)
  wall : wall_config option;
      (** Optional defensive party member that absorbs damage during ball
          throws. When [None], survival heals the active member in place and
          ball throws happen directly. *)
  ball_name : string;  (** Name of the Poké Ball to throw. *)
  max_balls : int;  (** Pause for user once this many balls have been thrown. *)
  foe_hp_target : float;
      (** Initial foe HP ratio threshold above which chipping runs. *)
  foe_hp_rechip : float;
      (** Higher foe HP ratio threshold used after balls have been thrown, to
          re-chip foes that heal (e.g. Aqua Ring or Rest). *)
  reapply_status : bool;
      (** When [true], re-apply status whenever the foe is observed {!Healthy}.
      *)
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
