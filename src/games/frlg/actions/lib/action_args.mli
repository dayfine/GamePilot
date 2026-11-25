(** Reading a game action's args from its plan event, with errors that name the
    action and the field
    (["give_bag_item: target_slot is 7, not a party slot (1-6)."]). A wrong arg
    fails the action as [bad_args], which repeats: the plan has to change. *)

type member =
  | Species of string  (** The party member of this species (a slug). *)
  | Slot of int  (** The member in this party slot, from 1. *)

val decode :
  action:string ->
  (where:string -> Json_field.obj -> 'a) ->
  Json_field.obj ->
  ('a, Checkpoints_run.Failure.cause) result
(** Runs the reader on the args with ["<action>: "] as [where]. *)

val party_slots : int
(** 6. *)

val slot : where:string -> string -> Json_field.obj -> int
(** The int field, which must be a party slot (1 to {!party_slots}). *)

val member : where:string -> Json_field.obj -> member
(** ["species"] if given, else ["target_slot"]; one of them is required. *)

val member_to_string : member -> string
(** ["mr-mime"] or ["slot 3"]. *)

val member_keys : string list
(** The args that name a party member an action uses or brings: ["species"],
    ["sweeper"], ["knock_off_species"], ["recycle_species"]. *)

val field_move_users : (string * string) list
(** The actions whose member the game picks itself, by the field move it must
    know: [cut_tree] (Cut). Their ["species"] names that member for the
    pre-flight only. *)

val picks_member : action:string -> Json_field.obj -> bool
(** The action finds a member by its species in the party: its args name one
    ({!member_keys}) and the game does not pick it ({!field_move_users}). *)
