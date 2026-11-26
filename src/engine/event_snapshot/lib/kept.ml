type ('start, 'at) kept = { start : 'start; at : 'at option }

module type FIELDS = sig
  type t

  val fields : t -> (string * Yojson.Safe.t) list
  val of_fields : (string * Yojson.Safe.t) list -> (t, string) result
end

module type AT = sig
  type t

  val to_yojson : t -> Yojson.Safe.t
  val of_yojson : Yojson.Safe.t -> (t, string) result
end

let ( let* ) = Result.bind

module Make (Start : FIELDS) (At : AT) = struct
  type t = (Start.t, At.t) kept

  let at_json = function None -> `Null | Some at -> At.to_yojson at
  let to_yojson k = `Assoc (Start.fields k.start @ [ ("at", at_json k.at) ])

  let at_of_json = function
    | None | Some `Null -> Ok None
    | Some json -> Result.map Option.some (At.of_yojson json)

  let of_yojson = function
    | `Assoc fields ->
        let start_fields = List.filter (fun (key, _) -> key <> "at") fields in
        let* start = Start.of_fields start_fields in
        let* at = at_of_json (List.assoc_opt "at" fields) in
        Ok { start; at }
    | _ -> Error "Kept: not a JSON object"
end
