open Engine_saved

module Start = struct
  type t = int option

  let fields gold =
    [ ("start_gold", match gold with None -> `Null | Some n -> `Int n) ]

  let of_fields fields =
    match List.assoc_opt "start_gold" fields with
    | None | Some `Null -> Ok None
    | Some (`Int n) -> Ok (Some n)
    | Some _ -> Error "start_gold is not a number"
end

include Kept.Make (Start) (Zone_saved)
