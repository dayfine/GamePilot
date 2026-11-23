(** The party's species by slot, as the game reckons it. FireRed has no reader
    for a member's species yet, so the program states the party at the
    checkpoint's start and the actions that change it (a swap, a trade, a prize)
    update it, as the overworld reckons the player's position. *)

type t
(** Slot 1 first; at most six members. *)

val of_list : string list -> t
(** Species slugs (["pidgey"]), slot 1 first. Raises [Invalid_argument] for more
    than six. *)

val of_string : string -> t
(** A comma-separated list: ["blastoise,pidgey,abra"]; [""] is no party. *)

val to_list : t -> string list
val size : t -> int

val slot_of : t -> string -> int option
(** The first slot (from 1) holding the species. *)

val resolve : t -> Action_args.member -> (int, Story.Failure.cause) result
(** A member's slot; a species not in the party fails as [not_in_party]. *)

val swap : t -> int -> int -> t
(** The members of the two slots (from 1) traded places. *)

val replace : t -> slot:int -> string -> t
(** The slot's member is now this species (an in-game trade). *)

val add : t -> string -> t
(** The species joins after the last member; a full party sends it to the PC, so
    the party stays as it was. *)
