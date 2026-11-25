(** How a plan writes promises with a position
    ({!Engine_rules.Promises.with_position}): the [postconditions] (or [until])
    object's [position] is read by the pose's decoder, the other keys by the
    promises' decoder, and a field neither owns is an error. *)

(** The pose's plan decoder. *)
module type POSE_DECODE = sig
  type t

  val pose_of_plan : where:string -> Json_field.obj -> (t, string) result
  (** The pose the [position] object writes; [where] names it in errors. *)
end

(** A set of promises' plan decoder. *)
module type PROMISES_DECODE = sig
  type t

  val keys : string list
  (** The keys of the postconditions object it reads, as plans write them. *)

  val promises_of_plan : where:string -> Json_field.obj -> (t, string) result
  (** The promises, read from their {!keys} only: the pair checks the object's
      other fields. *)
end

(** The decoder over the pose [P] and the promises [R]. *)
module Make (P : POSE_DECODE) (R : PROMISES_DECODE) : sig
  val postconditions_of_plan :
    where:string ->
    Json_field.obj ->
    ((P.t, R.t) Engine_rules.Promises.with_position, string) result
  (** A [postconditions] or [until] object. *)
end
