(** The party's species by slot, as the game reckons it: read from the members'
    summaries ({!Party_species}) before the first action that finds a member by
    its species, or stated (a test, [--party] on one checkpoint), and then
    updated by the actions that change it (a swap, a trade, a prize), as the
    overworld reckons the player's position. Reading it, not taking a declared
    party, keeps a member's slot right on a save whose other members differ. *)

type t
(** Slot 1 first; at most six members. *)

val of_list : string list -> t
(** Species slugs (["pidgey"]), slot 1 first. Raises [Invalid_argument] for more
    than six. *)

val of_read : string option list -> t
(** A party as {!Party_species.read_all} read it; a member whose species did not
    read is ["?"], which no species finds. *)

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
