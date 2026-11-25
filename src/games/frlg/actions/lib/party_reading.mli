(** The party a checkpoint's actions find members in: the one stated (a test,
    [--party] on one checkpoint), else read from the members' summaries
    ({!Party_species}) before the first game action that finds a member by its
    species ({!Action_args.picks_member}). A declared party's other members
    would shift the slots on a save whose fillers differ; the party as read does
    not. GamePilot's own: the fork's party tracker starts from its program's
    settings. *)

type t

val create : log:(string -> unit) -> Party_roster.t option -> t
(** [None]: read when first needed. *)

val roster : t -> Party_roster.t ref
(** The party as reckoned: the actions that change it (a swap, a trade, a prize)
    update it. Empty until read when none was stated. *)

val guard :
  t ->
  string * Checkpoints_run.Game.game_action ->
  string * Checkpoints_run.Game.game_action
(** The named action, with the party read first when it picks a member and the
    party is not known yet; a read that fails fails the action. *)
