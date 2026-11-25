(* A ["fly"] game action's args. *)

type request = { town : Fly_towns.town; user : Fly_user.user option }

let default_fly_row = 2
let where = "fly: "

let menu_row args =
  match Json_field.find "menu_row" args with
  | Some (`Int row) -> row
  | _ -> default_fly_row

let user args =
  match Json_field.find "slot" args with
  | Some _ ->
      Some
        {
          Fly_user.slot = Json_field.int ~where "slot" args;
          menu_row = menu_row args;
        }
  | None -> None

let town_named name =
  Result.bind (Fly_towns.load ()) (fun towns ->
      Option.to_result
        ~none:(name ^ " is no Fly destination")
        (Fly_towns.find towns name))

(* The user is any member that knows Fly: a plan names none. *)
let no_species args =
  if Json_field.has "species" args then
    Json_field.fail
      "%sspecies: a Fly uses the first member that knows Fly; give a slot to \
       pick one."
      where

let decode args =
  match
    no_species args;
    let name = Json_field.string ~where "town" args in
    (name, user args)
  with
  | exception Json_field.Invalid e -> Error e
  | name, user -> Result.map (fun town -> { town; user }) (town_named name)

let plan request (user : Fly_user.user) =
  { Fly.town = request.town; slot = user.slot; menu_row = user.menu_row }
