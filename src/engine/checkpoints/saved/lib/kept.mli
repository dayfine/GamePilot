(** What a run keeps beside an event's state, built from pieces: the promises'
    start reads and the pose's observed position
    ([docs/design/Composable-Rules.md], "The formats"). The file is [Start]'s
    fields in order, then ["at"]: one game's derived record, written field by
    field, stays byte-identical. *)

type ('start, 'at) kept = {
  start : 'start;
      (** What the run read at the checkpoint's start for a promise of a change.
      *)
  at : 'at option;  (** Where the player was reckoned to stand. *)
}

(** The start reads as the file's fields. *)
module type FIELDS = sig
  type t

  val fields : t -> (string * Yojson.Safe.t) list
  (** The fields, in file order. *)

  val of_fields : (string * Yojson.Safe.t) list -> (t, string) result
  (** What {!fields} wrote, given the file's fields but ["at"]. A missing key
      reads as unread, so an older file with fewer fields still loads. *)
end

(** The observed pose's JSON, as [[@@deriving yojson]] writes it. *)
module type AT = sig
  type t

  val to_yojson : t -> Yojson.Safe.t
  val of_yojson : Yojson.Safe.t -> (t, string) result
end

(** The saved file over the start reads [Start] and the observed pose [At]. *)
module Make (Start : FIELDS) (At : AT) :
  Event_states.SAVED with type t = (Start.t, At.t) kept
