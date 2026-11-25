(* A plan's declared preconditions (Plan_preconditions) and how the pre-flight
   judges them on the Trainer Card as read (Preflight.compare): the badges and
   the Hall of Fame a post-Elite Four program (the Sevii Islands chain, sb-01)
   needs. The plan is tt-01's with its metadata replaced; the card is a
   Trainer_card_front.t as the reader would give it, with no frame behind it. *)

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
  match Plan_preconditions.needs (with_preconditions json) with
  | Ok needs -> String.concat "; " (List.map Preflight.describe needs)
  | Error e -> "error: " ^ e

let case name input expectation = { Table_test.name; input; expectation }

let card earned stars : Card.t =
  { badges = List.init 8 (fun i -> i < earned); stars }

(* The pre-flight's rows for the declared needs on this card (and this caught
   count, off the same card), and go or stop. *)
let judge ?caught json card =
  match Plan_preconditions.needs (with_preconditions json) with
  | Error e -> Error e
  | Ok needs ->
      let read : Preflight.read =
        {
          observed =
            { Pokemon_engine.Postcondition_check.nothing_read with caught };
          place = None;
          members = None;
          card;
        }
      in
      let rows = Preflight.compare needs read in
      Ok (rows, Preflight.passed rows)

let verdict_text : Preflight.verdict -> string = function
  | Ok -> "ok"
  | Mismatch -> "MISMATCH"
  | Not_read -> "NOT READ"

(* One case per fact of a judged card: how many rows, each row's need, read
   (naming what is missing) and verdict, and go or stop. *)
let judged ?caught name json card ~rows ~go =
  let judged = lazy (judge ?caught json card) in
  let fact what f expected =
    case
      (name ^ ": " ^ what)
      (fun () ->
        match Lazy.force judged with
        | Error e -> "error: " ^ e
        | Ok (rows, passed) -> f rows passed)
      expected
  in
  let row_facts i (need, read, verdict) =
    let field label get expected =
      fact
        (Printf.sprintf "row %d, %s" (i + 1) label)
        (fun rows _ ->
          match List.nth_opt rows i with Some r -> get r | None -> "no row")
        expected
    in
    [
      field "need" (fun (r : Preflight.row) -> r.need) need;
      field "read" (fun (r : Preflight.row) -> r.read) read;
      field "verdict"
        (fun (r : Preflight.row) -> verdict_text r.verdict)
        verdict;
    ]
  in
  fact "rows"
    (fun rows _ -> string_of_int (List.length rows))
    (string_of_int (List.length rows))
  :: List.concat (List.mapi row_facts rows)
  @ [ fact "go or stop" (fun _ passed -> if passed then "go" else "stop") go ]

let sevii = {|{"badges": 8, "hall_of_fame": true}|}

let decode_cases =
  [
    case "none declared"
      (fun () ->
        match Plan_preconditions.needs { base with metadata = None } with
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
    case "the National Dex's 60 caught"
      (declared {|{"caught": 60}|})
      "at least 60 species caught";
    case "a caught count over the National Dex"
      (declared {|{"caught": 387}|})
      "error: metadata.preconditions.caught: 387 is not 0 to 386";
    case "a caught count as a word"
      (declared {|{"caught": "sixty"}|})
      "error: metadata.preconditions.caught: a count of species caught";
    case "the caught count is read for its need"
      (fun () ->
        match (Preflight.to_read [ Preflight.Caught_at_least 60 ]).caught with
        | Some _ -> "read"
        | None -> "not read")
      "read";
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

(* Whether each need asks anything of the save: one case per need, named by its
   text, so a regression names the need that changed (review rule R2). *)
let asks_cases =
  let asks expected need =
    case
      ("asks: " ^ Plan_needs.describe need)
      (fun () ->
        if Plan_needs.asks_something need then "something" else "nothing")
      expected
  in
  List.map (asks "nothing")
    [
      Plan_needs.Money_at_least { amount = 0; for_ = "buy" };
      Item_at_least { item = "retro-mail"; count = 0; for_ = "give" };
      Badges_at_least 0;
      Caught_at_least 0;
      Badges [];
      Party_in_order [];
      Party_includes { members = []; slots = [] };
    ]
  @ List.map (asks "something")
      [
        Plan_needs.Money_at_least { amount = 1; for_ = "buy" };
        Item_at_least { item = "retro-mail"; count = 99; for_ = "give" };
        Item_exactly { item = "retro-mail"; count = 0 };
        Badges_at_least 8;
        Member { species = "pidgey"; for_ = "fly" };
        No_mail { species = "mr-mime"; for_ = "trade" };
      ]

let eight =
  "8 badges (boulder, cascade, thunder, rainbow, soul, marsh, volcano, earth), \
   1 star"

let five = "5 badges (boulder, cascade, thunder, rainbow, soul), no star"

let judge_cases =
  List.concat
    [
      judged "a post-Elite Four save" sevii
        (Some (card 8 1))
        ~rows:
          [
            ("at least 8 badges", eight, "ok");
            ("the Hall of Fame entered", eight ^ ": entered", "ok");
          ]
        ~go:"go";
      judged "five badges, no star" sevii
        (Some (card 5 0))
        ~rows:
          [
            ("at least 8 badges", five ^ "; 3 short", "MISMATCH");
            ( "the Hall of Fame entered",
              "no star: the Hall of Fame not entered",
              "MISMATCH" );
          ]
        ~go:"stop";
      judged "named badges" {|{"badges": ["thunder", "soul", "marsh"]}|}
        (Some (card 5 0))
        ~rows:
          [
            ("badges thunder, soul, marsh", five ^ "; missing marsh", "MISMATCH");
          ]
        ~go:"stop";
      judged "60 caught, 61 on the card" {|{"caught": 60}|} None ~caught:61
        ~rows:[ ("at least 60 species caught", "61 caught", "ok") ]
        ~go:"go";
      judged "60 caught, 12 on the card" {|{"caught": 60}|} None ~caught:12
        ~rows:
          [ ("at least 60 species caught", "12 caught; 48 short", "MISMATCH") ]
        ~go:"stop";
      judged "60 caught, the count not read" {|{"caught": 60}|} None
        ~rows:[ ("at least 60 species caught", "not read", "NOT READ") ]
        ~go:"stop";
      judged "the card not read" sevii None
        ~rows:
          [
            ("at least 8 badges", "not read", "NOT READ");
            ("the Hall of Fame entered", "not read", "NOT READ");
          ]
        ~go:"stop";
    ]

let () =
  Table_test.run "plan preconditions" (decode_cases @ asks_cases @ judge_cases)
