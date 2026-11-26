(** plza.claim-gifts' checkpoints on the Switch
    (Plza_checkpoint_series.Checkpoint_series), each attempt through
    {!Plza_claim_gifts.Live_gift_steps.game} and the engine: the PLZA readers'
    templates uploaded, the screen woken ({!Switch_home.Stick_wake}), then the
    plan's events, whose first reads its start (the main menu and the party).
    Its plan has no [start] and no [retries]: one attempt, with no reload, which
    would lose the gifts not yet saved. Its daemons keep the console awake with
    the right stick, which does nothing in a menu
    (Plza_checkpoint_series.Checkpoint_series.keepawake_stick). Every plan is
    checked ({!Plza_claim_gifts.Claim_gifts.check_plan}) before the console
    moves. *)

type inputs = {
  catalog : Plza_gift_catalog.Gift_catalog.t;  (** The gifts, in claim order. *)
  today : Plza_gift_catalog.Gift_catalog.date;  (** The host's day (UTC). *)
  name_templates : (string * string) list;
      (** Each Internet gift's name template in the run's language, as PNG
          bytes, by gift id. *)
}
(** What a run is given, read before it starts: the program reads no clock and
    no file. *)

val run_series :
  inputs ->
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series inputs ~program ~options ~viewport plan_dir args]:
    {!Plza_checkpoint_series.Checkpoint_series.run_series} with claim-gifts'
    attempts; [program] is run.json's program fields. *)
