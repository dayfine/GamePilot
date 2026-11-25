module Card = Frlg_readers.Trainer_card_front

let ( let* ) = Result.bind
let where = "metadata.preconditions"

let badge_name = function
  | `String name when List.mem name Card.badge_names -> Ok name
  | `String name ->
      Error
        (Printf.sprintf "%s.badges: %S is not a badge (%s)" where name
           (String.concat ", " Card.badge_names))
  | _ -> Error (where ^ ".badges: a badge is named by a string")

let all_ok results =
  List.fold_right
    (fun r acc ->
      let* x = r in
      let* rest = acc in
      Ok (x :: rest))
    results (Ok [])

let badges : Yojson.Safe.t -> (Plan_needs.need, string) result = function
  | `Int n when n >= 0 && n <= List.length Card.badge_names ->
      Ok (Plan_needs.Badges_at_least n)
  | `Int n -> Error (Printf.sprintf "%s.badges: %d is not 0 to 8" where n)
  | `List names ->
      let* names = all_ok (List.map badge_name names) in
      Ok (Plan_needs.Badges names)
  | _ -> Error (where ^ ".badges: a count or a list of badge names")

let hall_of_fame : Yojson.Safe.t -> (Plan_needs.need, string) result = function
  | `Bool true -> Ok Plan_needs.Hall_of_fame
  | _ -> Error (where ^ ".hall_of_fame: only true")

let field (key, value) =
  match key with
  | "badges" -> badges value
  | "hall_of_fame" -> hall_of_fame value
  | _ -> Error (Printf.sprintf "%s.%s is not a known field." where key)

let needs (plan : Pokemon_checkpoints.Plan.t) =
  match Option.bind plan.metadata (List.assoc_opt "preconditions") with
  | None -> Ok []
  | Some (`Assoc fields) -> all_ok (List.map field fields)
  | Some _ -> Error (where ^ " is not an object.")
