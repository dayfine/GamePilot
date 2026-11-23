(** Which gates are open and which switches are on, across maps. *)

module Names : Set.S with type elt = string

type t = {
  opened : Names.t;  (** The flag gates opened, each as {!gate_key}. *)
  switches_on : Names.t;
      (** The switches (by id) that are on. One not here is off, as at a new
          game. *)
}

type change = {
  newly_opened : Names.t;  (** Gates the step opens, as {!gate_key}. *)
  switches : (string * bool) list;
      (** Each switch the step sets, with its new state (on or off), by id. *)
}
(** What a step does to a state. *)

val new_game : t
(** Nothing opened, every switch off. *)

val gate_key : map:string -> gate:string -> string
(** Names a gate across maps: ["SilphCo_5F/door_1"]. *)

val switch_on : t -> string -> bool

val apply : t -> change -> t
(** The state after the change: its gates opened and its switches set. *)

val change_between : before:t -> after:t -> change
(** The change that takes [before] to [after]: the gates [after] has opened that
    [before] has not, and the switches whose state differs (sorted by id). A
    flag gate does not close again, so one [before] has opened and [after] has
    not is ignored. *)

val equal : t -> t -> bool
