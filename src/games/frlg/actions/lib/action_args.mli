(** Reading a game action's args from its plan event, with errors that name the
    action and the field
    (["give_bag_item: target_slot is 7, not a party slot (1-6)."]). A wrong arg
    fails the action as [bad_args], which repeats: the plan has to change. *)

type member =
  | Species of string  (** The party member of this species (a slug). *)
  | Slot of int  (** The member in this party slot, from 1. *)

val decode :
  action:string ->
  (where:string -> Grid_maps.Json_field.obj -> 'a) ->
  Grid_maps.Json_field.obj ->
  ('a, Story.Failure.cause) result
(** Runs the reader on the args with ["<action>: "] as [where]. *)

val party_slots : int
(** 6. *)

val slot : where:string -> string -> Grid_maps.Json_field.obj -> int
(** The int field, which must be a party slot (1 to {!party_slots}). *)

val member : where:string -> Grid_maps.Json_field.obj -> member
(** ["species"] if given, else ["target_slot"]; one of them is required. *)

val member_to_string : member -> string
(** ["mr-mime"] or ["slot 3"]. *)
