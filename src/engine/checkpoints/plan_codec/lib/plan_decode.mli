(** Reads a checkpoint plan file ([gamepilot-checkpoint/1], or its old name
    [pokesim-authored-checkpoint/1]) into an {!Engine_plan.Plan.Make.t}, with
    the game's poses, kinds and promises read by its codec
    ({!Plan_codec.PLAN_CODEC}).

    It is as strict as PokemonSimulation's reader on the record: unknown fields,
    kinds and built-in args, missing required fields, malformed poses and
    repeated event ids are errors, each naming the file and the field, as in
    ["01-celadon-setup.plan.json: checkpoint.events[1].args.target.map is
     missing."]. It does not check a game action's args (the game does, when it
    binds the action) nor the game's [execution] settings. *)

val format : string
(** ["gamepilot-checkpoint/1"], what a plan file names and what is written. *)

val old_format : string
(** ["pokesim-authored-checkpoint/1"], the format's name before GamePilot owned
    it, still read as {!format}. *)

(** The decoder of the game's plans. *)
module Make
    (T : Engine_terms.TERMS)
    (_ : Plan_codec.PLAN_CODEC with module T = T) : sig
  val format : string
  (** {!Plan_decode.format}. *)

  val decode :
    source:string ->
    Yojson.Safe.t ->
    (Engine_plan.Plan.Make(T)(Raw_json).t, string) result
  (** The plan in the JSON; [source] names it in errors (the file name). *)

  val load : string -> (Engine_plan.Plan.Make(T)(Raw_json).t, string) result
  (** The plan in the file at the path, named by its base name in errors. *)
end
