(* A plan's declared preconditions (Plan_preconditions) and how the pre-flight
   judges them on the Trainer Card as read (Preflight.compare): the badges and
   the Hall of Fame a post-Elite Four program (the Sevii Islands chain, sb-01)
   needs. The plan is tt-01's with its metadata replaced. *)

open Frlg_checkpoints
module Card = Frlg_readers.Trainer_card_front

let base =
  match Plan_file.load "tt-01.plan.json" with
  | Ok p -> p
  | Error e -> failwith e

let with_preconditions json =
  {
    base with
    metadata = Some [ ("preconditions", Yojson.Safe.from_string json) ];
  }

let declared json () =
  match Preflight.declared (with_preconditions json) with
  | Ok needs -> String.concat "; " (List.map Preflight.describe needs)
  | Error e -> "error: " ^ e

let case name input expectation = { Table_test.name; input; expectation }

let card earned stars : Card.t =
  { badges = List.init 8 (fun i -> i < earned); stars }

let judged json card () =
  match Preflight.declared (with_preconditions json) with
  | Error e -> "error: " ^ e
  | Ok needs ->
      let read : Preflight.read =
        {
          observed = Checkpoints.Postcondition_check.nothing_read;
          place = None;
          members = None;
          card;
        }
      in
      let rows = Preflight.compare needs read in
      String.concat " | "
        (List.map
           (fun (r : Preflight.row) ->
             Printf.sprintf "%s: %s: %s" r.need r.read
               (match r.verdict with
               | Ok -> "ok"
               | Mismatch -> "MISMATCH"
               | Not_read -> "NOT READ"))
           rows)
      ^ if Preflight.passed rows then " => go" else " => stop"

let sevii = {|{"badges": 8, "hall_of_fame": true}|}

let decode_cases =
  [
    case "none declared"
      (fun () ->
        match Preflight.declared { base with metadata = None } with
        | Ok [] -> "none"
        | _ -> "some")
      "none";
    case "a count and the Hall of Fame" (declared sevii)
      "at least 8 badges; the Hall of Fame entered";
    case "badges by name"
      (declared {|{"badges": ["boulder", "soul"]}|})
      "badges boulder, soul";
    case "a count over 8"
      (declared {|{"badges": 9}|})
      "error: metadata.preconditions.badges: 9 is not 0 to 8";
    case "a badge not known"
      (declared {|{"badges": ["gold"]}|})
      "error: metadata.preconditions.badges: \"gold\" is not a badge (boulder, \
       cascade, thunder, rainbow, soul, marsh, volcano, earth)";
    case "hall_of_fame false"
      (declared {|{"hall_of_fame": false}|})
      "error: metadata.preconditions.hall_of_fame: only true";
    case "a field not known"
      (declared {|{"pokedex": 60}|})
      "error: metadata.preconditions.pokedex is not a known field.";
    case "a list, as the drafts write them"
      (declared {|[{"fact": "badges: 8"}]|})
      "error: metadata.preconditions is not an object.";
    case "reads the card only for these needs"
      (fun () ->
        Printf.sprintf "%b %b"
          (Preflight.reads_card [ Preflight.Hall_of_fame ])
          (Preflight.reads_card [ Preflight.Place "CeladonCity" ]))
      "true false";
  ]

let judge_cases =
  [
    case "a post-Elite Four save: go"
      (judged sevii (Some (card 8 1)))
      "at least 8 badges: 8 badges (boulder, cascade, thunder, rainbow, soul, \
       marsh, volcano, earth), 1 star: ok | the Hall of Fame entered: 8 badges \
       (boulder, cascade, thunder, rainbow, soul, marsh, volcano, earth), 1 \
       star: entered: ok => go";
    case "five badges, no star: refused, naming what is missing"
      (judged sevii (Some (card 5 0)))
      "at least 8 badges: 5 badges (boulder, cascade, thunder, rainbow, soul), \
       no star; 3 short: MISMATCH | the Hall of Fame entered: no star: the \
       Hall of Fame not entered: MISMATCH => stop";
    case "named badges: the missing ones named"
      (judged {|{"badges": ["thunder", "soul", "marsh"]}|} (Some (card 5 0)))
      "badges thunder, soul, marsh: 5 badges (boulder, cascade, thunder, \
       rainbow, soul), no star; missing marsh: MISMATCH => stop";
    case "the card not read: refused" (judged sevii None)
      "at least 8 badges: not read: NOT READ | the Hall of Fame entered: not \
       read: NOT READ => stop";
  ]

let () = Table_test.run "plan preconditions" (decode_cases @ judge_cases)
