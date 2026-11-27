(** Validated run options for the [bdsp.static_rng] static legendary RNG
    program.

    GamePilot's own option decoder over {!Run_options}, mapping CLI keys
    ([target], [shiny], [delay_ms], [sync], [max_attempts],
    [munchlax_timeout_s]) into typed parameters for {!Static_rng_workflow}. *)

(** Which shiny class a target advance must satisfy. *)
type shiny_filter =
  | Any  (** Accept either star or square shiny. *)
  | Star  (** Accept only star shiny. *)
  | Square  (** Accept only square shiny. *)

type t = {
  target : Bdsp_rng.Static_targets.t;
      (** Static legendary encounter descriptor (default Kyogre). *)
  shiny : shiny_filter;  (** Required shiny class (default {!Any}). *)
  delay_ms : int;
      (** Calibration offset in ms added to the timed confirm press (default
          200). *)
  sync_nature : int option;
      (** Optional Synchronize lead nature index (0..24), or [None]. *)
  max_attempts : int;
      (** Maximum soft-reset attempts before stopping (default 20). *)
  munchlax_timeout_s : int;
      (** Maximum seconds to wait for Munchlax boot-seed recovery per attempt
          (default 300). *)
}
(** Decoded and validated configuration for one [bdsp.static_rng] run. *)

val accept_pokemon : shiny_filter -> Bdsp_rng.Static_encounter.pokemon -> bool
(** [true] when [pokemon.shiny] matches the requested {!shiny_filter}. *)

val of_run_options : Run_options.t -> (t, string) result
(** Decodes and validates [bdsp.static_rng] options from checked
    {!Run_options.t}. *)

val format_summary : t -> string
(** One-line summary of the active run configuration for startup logs. *)
