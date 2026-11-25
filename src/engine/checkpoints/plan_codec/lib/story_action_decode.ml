module F = Json_field
open Engine_rules.Story_action

type t = Engine_rules.Story_action.t

let no_args action ~where:_ _ = action
let answer ~where args = Answer (F.bool_or ~where ~default:true "yes" args)

(* Each action: its name, the args it takes, and how to read them. *)
let actions =
  [
    ("talk", [], no_args Talk);
    ("scene", [], no_args Scene);
    ("save", [], no_args Save);
    ("answer", [ "yes" ], answer);
  ]

let names = List.map (fun (name, _, _) -> name) actions

let read allowed read ~where args =
  F.catch (fun () ->
      Plan_fields.known_fields_only ~where allowed args;
      read ~where args)

let of_plan name =
  List.find_map
    (fun (named, allowed, reader) ->
      if named = name then Some (read allowed reader) else None)
    actions
