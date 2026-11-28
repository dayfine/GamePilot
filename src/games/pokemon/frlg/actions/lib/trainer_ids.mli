(** Fallback trainer IDs ([tid] and [sid], 0..65535) loaded from
    [GAMEPILOT_FRLG_TID] / [GAMEPILOT_FRLG_SID] or [trainer_ids.json] in the
    FRLG config directory. *)

type t = {
  tid : int option;  (** Trainer ID, 0..65535. *)
  sid : int option;  (** Secret ID, 0..65535. *)
}
(** Fallback trainer IDs loaded from environment or config file. *)

val none : t
(** Both [tid] and [sid] unset. *)

val max_id : int
(** Maximum valid 16-bit ID ([65535]). *)

val env_var : string -> string
(** [env_var "tid"] is ["GAMEPILOT_FRLG_TID"]. *)

val config_file : string
(** ["trainer_ids.json"]. *)

val load : unit -> (t, string) result
(** Reads fallback trainer IDs from environment variables, falling back to
    [trainer_ids.json] inside the FRLG config directory. *)
