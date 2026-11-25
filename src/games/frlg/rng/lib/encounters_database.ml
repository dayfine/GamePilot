(* Port of EncountersDatabase (PokemonFRLG_EncountersDatabase.cpp). *)

type t = (string * (string * Wild_encounter.slot array) list) list

let ( let* ) = Result.bind

let all f items =
  List.fold_right
    (fun item acc ->
      let* rest = acc in
      let* x = f item in
      Ok (x :: rest))
    items (Ok [])

let level_of name fields =
  match List.assoc_opt name fields with
  | Some (`Int n) -> Ok n
  | _ -> Error ("an encounter slot without " ^ name)

let species_of fields =
  match List.assoc_opt "species" fields with
  | Some (`String s) -> Ok s
  | _ -> Error "an encounter slot without species"

let slot_of fields =
  let* species = species_of fields in
  let* min_level = level_of "minLevel" fields in
  let* max_level = level_of "maxLevel" fields in
  Ok { Wild_encounter.species; min_level; max_level }

let slot = function
  | `Assoc fields -> slot_of fields
  | _ -> Error "an encounter slot is not an object"

let location (name, v) =
  match v with
  | `List items ->
      let* slots = all slot items in
      Ok (name, Array.of_list slots)
  | _ -> Error ("location " ^ name ^ " is not an array")

let kind (name, v) =
  match v with
  | `Assoc locations ->
      let* locations = all location locations in
      Ok (name, locations)
  | _ -> Error ("encounter type " ^ name ^ " is not an object")

let of_json = function
  | `Assoc kinds -> all kind kinds
  | _ -> Error "the encounter slots file is not an object"

let slots t ~kind ~location =
  Option.bind (List.assoc_opt kind t) (List.assoc_opt location)
