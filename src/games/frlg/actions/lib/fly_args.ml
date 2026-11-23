(* A ["fly"] game action's args, decoded against the reckoned party. *)

let default_fly_row = 2
let where = "fly: "

let menu_row args =
  match Grid_maps.Json_field.find "menu_row" args with
  | Some (`Int row) -> row
  | _ -> default_fly_row

let flyer party args =
  match Grid_maps.Json_field.find "slot" args with
  | Some _ -> Ok (Grid_maps.Json_field.int ~where "slot" args)
  | None -> (
      let species = Grid_maps.Json_field.string ~where "species" args in
      match Party_roster.slot_of party species with
      | Some slot -> Ok slot
      | None -> Error (where ^ species ^ " is not in the party"))

let plan_for party town args =
  match flyer party args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | Error e -> Error e
  | Ok slot -> Ok { Fly.town; slot; menu_row = menu_row args }

let town_named name =
  Result.bind (Fly_towns.load ()) (fun towns ->
      Option.to_result
        ~none:(name ^ " is no Fly destination")
        (Fly_towns.find towns name))

let decode party args =
  match Grid_maps.Json_field.string ~where "town" args with
  | exception Grid_maps.Json_field.Invalid e -> Error e
  | name -> Result.bind (town_named name) (fun town -> plan_for party town args)
