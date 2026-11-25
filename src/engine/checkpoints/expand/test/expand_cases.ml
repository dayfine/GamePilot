(* What the expansion tests share: a plan around some events, and the events a
   rewrite gives, one compact JSON line each (or its error). *)

let plan ?(start = {|{"map": "Town", "tiles": [[1, 1]], "facing": "south"}|})
    events =
  Yojson.Safe.from_string
    (Printf.sprintf
       {|{"format": "gamepilot-checkpoint/1", "game": "test",
          "checkpoint": {"id": "t", "title": "t", "start": %s, "events": [%s]},
          "execution": {}}|}
       start
       (String.concat ", " events))

let event_lines json =
  match
    List.assoc_opt "events"
      Engine_expand.Plan_json.(object_field "checkpoint" (fields_of json))
  with
  | Some (`List events) -> List.map Yojson.Safe.to_string events
  | _ -> [ "no events" ]

(* The rewrite of a plan around [events], as lines. *)
let expanded rewrite ?start events () =
  match rewrite ~source:"t" (plan ?start events) with
  | Ok json -> String.concat "\n" (event_lines json)
  | Error e -> e

let case name input expectation = { Table_test.name; input; expectation }
