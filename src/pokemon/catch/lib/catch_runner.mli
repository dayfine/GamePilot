(** Game-agnostic catch loop driven by a game's {!game_steps}.

    Reads battle events from {!game_steps.next_event}, delegates action-menu
    decisions to {!Catch_policy.decide} and forced switch-ins to
    {!Catch_policy.next_send_in}, and pauses safely rather than risking a flee
    or uncontrolled input on any unexpected prompt or exhausted limit. *)

(** Next observable event in an ongoing wild catch battle. *)
type event =
  | Action_menu of Catch_state.t
      (** Main battle menu is ready with the observed {!Catch_state.t}. *)
  | Forced_switch of { fainted_slot : int }
      (** The active party member fainted and the game requires a replacement.
      *)
  | Caught  (** The wild Pokémon was caught and the battle ended. *)
  | Battle_lost  (** The player's party was defeated. *)
  | Unexpected of string
      (** Unrecognized screen or prompt; triggers a safe {!Paused} stop. *)

type game_steps = {
  next_event : unit -> (event, string) result;
      (** Wait for and read the next battle {!event}. *)
  execute : Catch_state.command -> (unit, string) result;
      (** Carry out a chosen {!Catch_state.command} at the action menu. *)
  send_in : int -> (unit, string) result;
      (** Send in the given 1-based party slot at a forced switch-in screen. *)
}
(** Game-specific reads and inputs supplied to {!run}. *)

type summary = {
  turns : int;  (** Number of action-menu commands executed. *)
  balls_thrown : int;  (** Number of Poké Balls thrown. *)
  switches : int;  (** Number of voluntary and forced switches executed. *)
  heals : int;
      (** Number of heals executed ({!Catch_state.Heal_active} or the wall's
          configured [heal_move_slot]). *)
}
(** Counters recorded over a catch attempt. *)

(** Terminal outcome of {!run}. *)
type outcome =
  | Caught of summary  (** Target caught. *)
  | Paused of { reason : string; summary : summary }
      (** Stopped safely for the player to take over (limit reached, unexpected
          screen, or no healthy send-in left). *)
  | Failed of { reason : string; summary : summary }
      (** Battle lost or a game step returned an error. *)

val empty_summary : summary
(** Zeroed {!summary} at the start of a catch attempt. *)

val run : ?log:(string -> unit) -> game_steps -> Catch_state.policy -> outcome
(** Run the catch loop until {!Caught}, {!Paused}, or {!Failed}. *)
