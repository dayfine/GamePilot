module Choices = Plza_story.New_game_choices

type t = {
  language : Choices.language option;
  look : int option;
  name : string option;
}

let none = { language = None; look = None; name = None }
let given t = t <> none

let over t (c : Choices.t) =
  {
    Choices.language = Option.value t.language ~default:c.language;
    look = Option.value t.look ~default:c.look;
    name = Option.value t.name ~default:c.name;
  }

(* The languages 01.00a types a name in. *)
let typed_tags =
  List.filter
    (fun tag ->
      match Choices.of_tag tag with
      | Some l -> (Choices.info l).typed
      | None -> false)
    Choices.tags

let language t tag =
  match Choices.of_tag tag with
  | Some l -> Ok { t with language = Some l }
  | None ->
      Error
        ("language is one of " ^ String.concat ", " typed_tags ^ ", not " ^ tag)

let look t v =
  match int_of_string_opt v with
  | Some n when n >= 1 && n <= Choices.looks -> Ok { t with look = Some n }
  | _ -> Error (Printf.sprintf "look is 1 to %d, not %s" Choices.looks v)

let name t v = Ok { t with name = Some v }

let check t =
  match Choices.problem (over t Choices.default) with
  | None -> Ok ()
  | Some why -> Error why

let describe (c : Choices.t) =
  Printf.sprintf "%s, look %d, \"%s\"" (Choices.info c.language).tag c.look
    c.name
