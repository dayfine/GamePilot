(* The engine's pieces on their own, as the toy game uses them: an action sum
   decoded from a list of parts (Action_parts), the check that no two parts
   own a name, the story set read and printed by the toy's plan format, and a
   command's steps by name (Command_step). A plan's talk, answer, scene and
   save are still the engine's own kinds, read before the game's (step 4 of
   docs/design/Composable-Rules.md moves them out), so the toy's story set is
   read here through its plan format. *)

open Engine_plan_format
open Toy_game

let case name input expectation = { Table_test.name; input; expectation }
let where = "p: checkpoint.events[0].args."

let args text =
  match Yojson.Safe.from_string text with `Assoc fields -> fields | _ -> []

(* A name read by the parts: the reader's result, or no part owning it. *)
let read action_of_plan show name json =
  match action_of_plan name with
  | None -> "no part owns " ^ name
  | Some read -> (
      match read ~where (args json) with
      | Ok action -> show action
      | Error message -> message)

let toy name json () =
  read Toy_plan_format.action_of_plan Toy_rules.Action.to_string name json

(* A third toy set that also owns [rest]: camping. *)
module Camp_decode = struct
  type t = Pitch_tent | Rest_by_fire

  let names = [ "pitch_tent"; "rest" ]
  let read action ~where:_ _ = Ok action

  let of_plan = function
    | "pitch_tent" -> Some (read Pitch_tent)
    | "rest" -> Some (read Rest_by_fire)
    | _ -> None
end

type with_camp = Toy of Toy_rules.Action.t | Camp of Camp_decode.t

let with_camp =
  List.map
    (fun (Action_parts.Part (decode, into)) ->
      Action_parts.Part (decode, fun a -> Toy (into a)))
    Toy_plan_format.parts
  @ [ Action_parts.Part ((module Camp_decode), fun c -> Camp c) ]

let claimed parts () =
  match Action_parts.claimed_twice parts with
  | [] -> "none"
  | names -> String.concat ", " names

(* A command's generated plan: the story set and the command's steps. *)
type command_action =
  | Story of Engine_rules.Story_action.t
  | Command of Engine_rules.Command_step.t

let command_parts =
  Action_parts.
    [
      Part ((module Story_action_decode), fun a -> Story a);
      Part
        ( Command_step_decode.of_names [ "soft_reset"; "read_party" ],
          fun s -> Command s );
    ]

let command name json () =
  read
    (Action_parts.action_of_plan command_parts)
    (function
      | Story a -> "story " ^ Engine_rules.Story_action.to_string a
      | Command s -> "step " ^ Engine_rules.Command_step.to_string s)
    name json

let cases =
  [
    case "the toy's walk set: its constructor, printed"
      (toy "walk" {|{"toward": "n", "until": "sign"}|})
      "walk n until sign";
    case "the toy's inn set: buy, printed"
      (toy "buy" {|{"item": "bell"}|})
      "buy bell";
    case "the engine's story set in the toy's sum: answer no"
      (toy "answer" {|{"yes": false}|})
      "answer no";
    case "the story set's answer reads yes by default" (toy "answer" "{}")
      "answer yes";
    case "an unknown arg of the story set's talk, named by its decoder"
      (toy "talk" {|{"to": "cat"}|})
      "p: checkpoint.events[0].args.to is not a known field.";
    case "a name no part of the toy owns" (toy "route" "{}")
      "no part owns route";
    case "the toy's parts own every name once"
      (claimed Toy_plan_format.parts)
      "none";
    case "a third set that also owns rest: the check names it"
      (claimed with_camp) "rest";
    case "a clash: the first part that owns the name reads it"
      (fun () ->
        read
          (Action_parts.action_of_plan with_camp)
          (function
            | Toy a -> "toy " ^ Toy_rules.Action.to_string a | Camp _ -> "camp")
          "rest" "{}")
      "toy rest";
    case "a command's step, by name"
      (command "read_party" "{}")
      "step read_party";
    case "a command's step takes no args"
      (command "soft_reset" {|{"slot": 1}|})
      "p: checkpoint.events[0].args.slot is not a known field.";
    case "a name not in the command's steps" (command "verdict" "{}")
      "no part owns verdict";
    case "a command's plan beside the story set" (command "save" "{}")
      "story save";
    case "the story set and a command's steps own every name once"
      (claimed command_parts) "none";
  ]

let () = Table_test.run "toy_pieces" cases
