(** Room in the party before the chain (Frlg_checkpoints.Make_room, --make-room
    MAP): the party read in a pre-flight run of 00-make-room's own; none needed,
    the chain runs as it is; else 00-make-room's plan, written to a plan folder
    of its own, runs first. *)

val with_room :
  plan_dir:string ->
  from_id:string ->
  string option ->
  Preflight_command.setup ->
  (string * string, string) result
(** The plan folder and first checkpoint the series runs: [plan_dir] and
    [from_id] without --make-room or when no room is needed, else 00-make-room's
    folder and id. *)
