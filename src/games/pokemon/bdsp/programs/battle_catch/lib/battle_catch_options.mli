(** Validated run options for [bdsp.battle_catch].

    GamePilot's own option decoder over {!Run_options}, mapping CLI keys into a
    {!Pokemon_catch.Catch_state.policy} and
    {!Bdsp_actions.Battle_catch_steps.bag_layout} for catching a live BDSP
    encounter. *)

type t = {
  target : string;  (** Encounter preset label (e.g. [groudon], [kyogre]). *)
  lead_slot : int;  (** 1-based party slot sent out at battle start. *)
  bag : Bdsp_actions.Battle_catch_steps.bag_layout;
      (** Bag pocket and item row offsets for balls and healing items. *)
  fallback_ball_steps : int;
      (** X-carousel horizontal steps from primary ball to fallback ball. *)
  policy : Pokemon_catch.Catch_state.policy;
      (** Constructed catch policy including optional tank heavy-chipper. *)
}
(** Decoded configuration for one [bdsp.battle_catch] run. *)

val of_run_options : Run_options.t -> (t, string) result
(** Decodes and validates [bdsp.battle_catch] options from checked
    {!Run_options.t}. *)

val format_summary : t -> string
(** One-line startup summary of the active catch policy. *)
