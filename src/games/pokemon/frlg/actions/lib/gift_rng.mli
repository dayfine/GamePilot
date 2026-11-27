(** The ["gift_rng"] game action: timed Method 1 gift claims (such as Celadon
    Game Corner prizes) with Summary {!Frlg_readers.Shiny_star} confirmation.

    Reuses {!Frlg_rng.Gift_target} for shiny target search,
    {!Frlg_rng.Switch_rng_calibration} for Switch console offsets,
    {!Wild_rng_steps.title_presses} for the reset/title/continue sequence, and
    {!Wild_rng_steps.shiny_at} to confirm the shiny star in party slot 6. *)

type plan = {
  species : string;  (** The prize species to claim shiny, e.g. ["scyther"]. *)
  prize_row : int;
      (** Zero-based row in the Celadon Game Corner prize list (0..4; Scyther is
          3 in FireRed). *)
  tid : int;  (** Trainer ID, 0..65535. *)
  sid : int;  (** Secret ID, 0..65535. *)
  seeds : string;
      (** Seed table filename under [src/games/pokemon/frlg/assets/]. *)
  boot_offset_ms : int;  (** Console boot timing offset in ms (0 by default). *)
  seed_shift : int;  (** Wrapping 16-bit seed shift (0 by default). *)
  ingame_offset : int;
      (** Advances added to the in-game wait (-99..99, 0 by default). *)
  frame_model : string;  (** ["mgba"] or ["switch"]. *)
  min_advance : int;  (** Minimum RNG advance searched. *)
  max_advance : int;  (** Maximum RNG advance searched. *)
  attempts : int;  (** Maximum reset attempts (1..99, default 1). *)
}
(** Decoded arguments for one ["gift_rng"] action. *)

type game_steps = {
  claim_prize : unit -> bool;
      (** Hard-resets, executes the timed prize-claim presses, and settles back
          to the overworld. Returns [true] if the claim sequence completed. *)
  shiny_at : int -> bool;
      (** Checks party slot [slot] (1-based) for the Summary shiny star. *)
  log : string -> unit;  (** Logs progress messages. *)
}
(** What {!run} reads and does in the game. *)

(** How {!run} ended. *)
type end_ =
  | Shiny  (** The claimed gift showed the shiny star on Summary page 1. *)
  | Not_shiny  (** All attempts claimed a non-shiny Pokémon. *)
  | Claim_failed  (** The timed prize-claim sequence failed to complete. *)
  | Party_full
      (** The party already has 6 members, leaving no room for the gift. *)

type outcome = {
  end_ : end_;  (** Final outcome of the gift RNG attempt loop. *)
  attempts : int;  (** Number of reset attempts executed. *)
}
(** Outcome of {!run}. *)

val decode :
  ?options:Run_options.t ->
  ?fallback:Wild_rng_plan.trainer_ids ->
  ?default_frame_model:string ->
  Json_field.obj ->
  (plan, Pokemon_engine.Failure.cause) result
(** Decodes ["species"], ["prize_row"] (int or decimal string 0..4), optional
    ["tid"], ["sid"], ["seeds"], ["seed_shift"], ["ingame_offset"],
    ["frame_model"] (defaults to [default_frame_model], itself ["mgba"]),
    ["advances"], and ["attempts"]. *)

val apply_calibration : Frlg_rng.Switch_rng_calibration.entry -> plan -> plan
(** Applies a persisted per-console Switch calibration entry to [plan]. *)

val apply_timing_delta : boot_delta_ms:int -> ingame_delta:int -> plan -> plan
(** Adds [boot_delta_ms] to [plan.boot_offset_ms] and [ingame_delta] to
    [plan.ingame_offset]. *)

val target : plan -> (Frlg_rng.Gift_target.t, string) result
(** Reads the seed table and searches for the soonest shiny Method 1 gift target
    in [plan.min_advance .. plan.max_advance]. *)

val blind_presses : prize_row:int -> Frlg_rng.Rng_timings.t -> Wire.command list
(** From the reset: {!Wild_rng_steps.title_presses} followed by talking to the
    prize clerk, opening the prize list, scrolling [prize_row] rows down,
    selecting the prize, waiting the remaining in-game delay, and pressing A on
    YES to claim the gift at the target advance. *)

val live_game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  prize_row:int ->
  Frlg_rng.Rng_timings.t ->
  game_steps
(** Live {!game_steps} that reset via {!Rng_reset.reset_and_submit} (default
    {!Rng_reset.Mgba}), submit {!blind_presses}, decline any nickname prompt,
    settle back to the overworld, and check {!Wild_rng_steps.shiny_at}. *)

val live_calibrated_game_steps :
  log:(string -> unit) ->
  ?reset_mode:Rng_reset.mode ->
  plan ->
  Frlg_rng.Gift_target.t ->
  game_steps
(** Live {!game_steps} that recompute {!target} before each attempt and, on
    Switch ([plan.frame_model = "switch"]), read Summary Page 1 & Page 2 on
    misses, report the miss distance via {!Rng_miss_calibration}, update the
    in-memory plan offsets for the next attempt, and persist the timing delta.
*)

val run : game_steps -> attempts:int -> party:int -> outcome
(** Runs up to [attempts] timed gift claims, stopping as soon as the newly
    claimed Pokémon in slot [party + 1] shows the shiny star. *)

val failure_code : end_ -> string option
(** [None] for {!Shiny}; a short machine code for every failure end. *)

val message : outcome -> string
(** Human-readable summary of [outcome]. *)
