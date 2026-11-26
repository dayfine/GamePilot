module Choices = Plza_story.New_game_choices

type t = {
  language : Choices.language option;
  look : int option;
  name : string option;
}

let none = { language = None; look = None; name = None }

let over t (c : Choices.t) =
  {
    Choices.language = Option.value t.language ~default:c.language;
    look = Option.value t.look ~default:c.look;
    name = Option.value t.name ~default:c.name;
  }

let ( let* ) = Result.bind

let language options =
  match Option.map Choices.of_tag (Run_options.find options "language") with
  | None -> Ok None
  | Some (Some l) -> Ok (Some l)
  | Some None -> Error "--options language: not a language tag"

let check t =
  match Choices.problem (over t Choices.default) with
  | None -> Ok ()
  | Some why -> Error why

let of_run_options options =
  let* language = language options in
  let t =
    {
      language;
      look = Run_options.int options "look";
      name = Run_options.find options "name";
    }
  in
  let* () = check t in
  Ok t

let describe (c : Choices.t) =
  Printf.sprintf "%s, look %d, \"%s\"" (Choices.info c.language).tag c.look
    c.name
