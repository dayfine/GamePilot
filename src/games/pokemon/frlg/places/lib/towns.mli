(** The places table's [towns]: each town by its one key ([lavender],
    [indigo_plateau]), the prefix its places' names start with, and what a
    fragment's [town] parameter looks up there ([{town.nurse}]). *)

type town = {
  key : string;
  nurse : string;  (** The place in front of its Pokemon Center nurse. *)
  fly : string;
      (** Fly's name for it, the map Fly lands on: ["LavenderTown"]. *)
  mart : string option;  (** The place in front of its Mart clerk, if listed. *)
}
(** One town of the table. *)

type t
(** The towns, by key, in the file's order. *)

val parse :
  where:string -> places:string list -> Yojson.Safe.t -> (t, string) result
(** The [towns] object; [where] prefixes errors (["places.json: "]). A nurse or
    mart that is not one of [places] is an error. *)

val empty : t
(** No towns: a table without a [towns] section. *)

val towns : t -> town list
(** In the file's order. *)

val find : t -> string -> (town, string) result
(** The town of that key; an unknown key's error suggests the nearest. *)

val find_by_fly : t -> string -> town option
(** The town whose Fly map is that name (["ViridianCity"]), if listed. *)

val field : t -> string -> field:string option -> (string, string) result
(** A [town] parameter's value: the key itself ([None]), or its ["nurse"],
    ["fly"] or ["mart"]. *)
