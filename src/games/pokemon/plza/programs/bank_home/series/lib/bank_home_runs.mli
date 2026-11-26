(** plza.bank-home's checkpoints on the Switch
    (Plza_checkpoint_series.Checkpoint_series), each attempt through
    {!Plza_bank_home.Bank_home_game} and the engine: it first finds Legends:
    Z-A's tile on the Switch's HOME menu
    ({!Plza_bank_home.Bank_home_game.start_check}), then runs its events. A plan
    with no [start] and no [retries] is one attempt with no reload, so a failed
    bank leaves Pokémon HOME open, unsaved, for a look. Its daemons' keep-awake
    is left as given: the HOME menu and Pokémon HOME have no camera to nudge.
    Every plan is checked ({!Plza_bank_home.Bank_home_game.check_plan}) before
    the console moves. *)

val run_series :
  moves:Pokemon_home.Box_moves.t list ->
  program:(string * string) list ->
  options:Run_options.t ->
  viewport:(string option, string) result ->
  string ->
  string list ->
  (int, string) result
(** [run_series ~moves ~program ~options ~viewport plan_dir args]:
    {!Plza_checkpoint_series.Checkpoint_series.run_series} with bank-home's
    attempts, which move [moves] (the gift catalog's,
    {!Plza_bank_home.Catalog_moves.of_catalog}, read before the run); [program]
    is run.json's program fields. *)
