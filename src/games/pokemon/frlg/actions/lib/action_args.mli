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
  ('a, Pokemon_engine.Failure.cause) result
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

val named_species : where:string -> Json_field.obj -> string list
(** The species slugs named by {!member_keys} in the args, in key order. *)

val field_move_users : (string * string) list
(** The actions that use any member knowing a field move, so their args name no
    member: [cut_tree] (Cut: the game picks the member) and [fly] (Fly: the
    first member that knows it, {!Fly_user}). *)

val field_move_badges : (string * string) list
(** The badge each HM needs outside battle, by field move: [("fly", "thunder")]
    and the six others, from pret pokefirered [src/party_menu.c]. *)

val badge_needed : string -> string option
(** The badge the game checks before this action's field move
    ({!field_move_users}); [None] for an action with no field move. *)

val deposited_species : where:string -> Json_field.obj -> string list
(** [pc_deposit]'s ["species"]: a list, every member it stores, in order; [[]]
    when the args leave it out. *)

val picks_member : action:string -> Json_field.obj -> bool
(** The action finds a member by its species in the party: its args name one
    ({!member_keys}) and it uses no field move ({!field_move_users}); or it is a
    capture, which counts the party to know whether a catch joins it or goes to
    the PC; or a PC deposit, whose member may be named by what it holds and is
    looked for by its species. *)
