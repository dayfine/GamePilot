open Plza_story
module Failure = Engine_run.Failure
module Plan = Plza_checkpoints.Plan

let bad_args (event : Plan.event) detail =
  Error (Failure.cause ~repeats:true "bad_args" (event.id ^ ": " ^ detail))

(* 01.00a's choices: "language" (a tag), "look" (1 to 8) and "name", each
   optional, the fork's default when absent. *)
let language_choice (c : New_game_choices.t) event tag =
  match New_game_choices.of_tag tag with
  | Some language -> Ok { c with language }
  | None ->
      bad_args event
        ("language is one of "
        ^ String.concat ", " New_game_choices.tags
        ^ ", not " ^ tag)

let choice (c : New_game_choices.t) (event : Plan.event) = function
  | "language", `String tag -> language_choice c event tag
  | "look", `Int look -> Ok { c with look }
  | "name", `String name -> Ok { c with name }
  | key, _ ->
      bad_args event
        (key
       ^ ": the args are language (a tag), look (a whole number) and name (a \
          string)")

let choices ~options (event : Plan.event) (args : Json_field.obj) =
  Result.map
    (New_game_options.over options)
    (List.fold_left
       (fun acc arg -> Result.bind acc (fun c -> choice c event arg))
       (Ok New_game_choices.default) args)

let refused_options =
  "--language, --look and --name are 01.00a's new-game choices, and this \
   series has no new game: start it at 01.00a, or drop them"

let playable (checkpoint : Plan.checkpoint) c =
  match New_game_choices.problem c with
  | None -> Ok c
  | Some why -> Error (checkpoint.checkpoint_id ^ ": " ^ why)

let checked ~options checkpoint event args =
  Result.bind
    (Result.map_error Failure.cause_to_string (choices ~options event args))
    (playable checkpoint)

(* The choices [event] plays, when it is a new game. *)
let event_choices ~options checkpoint (event : Plan.event) =
  match (event.kind, event.way) with
  | Named_action args, Some "new_game" ->
      Some (checked ~options checkpoint event args)
  | _ -> None

let all_ok results =
  List.fold_right
    (fun r acc -> Result.bind r (fun c -> Result.map (List.cons c) acc))
    results (Ok [])

let series_choices ~options checkpoints =
  let found =
    List.concat_map
      (fun (cp : Plan.checkpoint) ->
        List.filter_map (event_choices ~options cp) cp.events)
      checkpoints
  in
  if found = [] && New_game_options.given options then Error refused_options
  else all_ok found
