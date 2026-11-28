(** plza.claim-gifts' checkpoints on the Switch
    (Plza_checkpoint_series.Checkpoint_series), each attempt through
    {!Plza_claim_gifts.Live_gift_steps.game} and the engine: the PLZA readers'
    templates uploaded, the screen woken ({!Switch.Stick_wake}), then the plan's
    events, whose first reads its start (the main menu and the party). Its plan
    has no [start] and no [retries]: one attempt, with no reload, which would
    lose the gifts not yet saved. Its daemons keep the console awake with the
    right stick, which does nothing in a menu
    (Plza_checkpoint_series.Checkpoint_series.keepawake_stick). Every plan is
    checked ({!Plza_claim_gifts.Claim_gifts.check_plan}) before the console
    moves. *)

val guide_blocks : (string * (unit -> (string, string) result)) list
(** Program-specific guide blocks for [plza.claim-gifts], by block name
    ([gifts]: the gift catalog table). *)

val run_series :
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~program ~options ~viewport plan_dir args]: loads the gift
    catalog, today's UTC date, and Internet gift name templates for [options]'s
    language ({!Plza_checkpoint_series.Gift_inputs}), then runs
    {!Plza_checkpoint_series.Checkpoint_series.run_series} with claim-gifts'
    attempts; [program] is run.json's program fields. *)
