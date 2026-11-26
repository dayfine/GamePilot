(* The Mystery Gift catalog: gifts.json decodes and passes its checks, its
   gifts' expiry against fixed days (no clock is read), its printed lines,
   and the decoder's refusals on one gift edited at a time. The gifts here
   are literals, not fakes of anything. *)

module C = Plza_gift_catalog.Gift_catalog
module D = Plza_gift_catalog.Gift_catalog_decode

let shipped () = D.of_json (Yojson.Safe.from_file "../gifts.json")

let decoded name = function
  | Ok catalog ->
      List.map (fun (g : C.gift) -> g.id) catalog |> String.concat " "
  | Error e -> name ^ ": " ^ e

let day s = Result.get_ok (C.date_of_string s)

let shipped_cases : Table_test.case list =
  [
    {
      name = "gifts.json decodes and passes its checks";
      input = (fun () -> decoded "gifts.json" (shipped ()));
      expectation = "vivillon-poke-ball xerneas-30th prepar1ng-items";
    };
  ]

let gift : C.gift =
  {
    id = "xerneas-30th";
    name = "Shiny Xerneas";
    how = Code;
    code = Some "CELEBRATE30TH";
    expires = day "2027-01-07";
    pokemon =
      Some
        {
          box_slot = { box = 1; slot = 1 };
          home_boxes = [ 165; 164 ];
          home_order = Pokemon_home.Box_view.Left_to_right;
        };
    source = "https://www.nintendolife.com/guides/x";
  }

let expired today () = string_of_bool (C.expired ~today:(day today) gift)

let date_cases : Table_test.case list =
  [
    {
      name = "the last day is not expired";
      input = expired "2027-01-07";
      expectation = "false";
    };
    {
      name = "the day after is expired";
      input = expired "2027-01-08";
      expectation = "true";
    };
    {
      name = "a year before is not";
      input = expired "2026-11-25";
      expectation = "false";
    };
    {
      name = "30 February is no day";
      input =
        (fun () ->
          Result.fold ~ok:C.date_to_string ~error:Fun.id
            (C.date_of_string "2026-02-30"));
      expectation = "\"2026-02-30\" is not a day written YYYY-MM-DD";
    };
    {
      name = "29 February of a leap year is a day";
      input =
        (fun () ->
          Result.fold ~ok:C.date_to_string ~error:Fun.id
            (C.date_of_string "2028-02-29"));
      expectation = "2028-02-29";
    };
    {
      name = "a gift's line";
      input = (fun () -> String.concat "" (C.lines [ gift ]));
      expectation = "xerneas-30th: Shiny Xerneas, by code, until 2027-01-07";
    };
  ]

(* A one-gift file with [field] set to [value], or left out for `Null. *)
let one_gift edits =
  let base =
    [
      ("id", `String "xerneas-30th");
      ("name", `String "Shiny Xerneas");
      ("how", `String "code");
      ("code", `String "CELEBRATE30TH");
      ("expires", `String "2027-01-07");
      ("box_slot", `Assoc [ ("box", `Int 1); ("slot", `Int 1) ]);
      ("home_boxes", `List [ `Int 165; `Int 164 ]);
      ("home_order", `String "left_to_right");
      ("source", `String "https://www.nintendolife.com/guides/x");
    ]
  in
  let fields =
    List.fold_left
      (fun fields (k, v) ->
        let rest = List.remove_assoc k fields in
        match v with `Null -> rest | v -> rest @ [ (k, v) ])
      base edits
  in
  `Assoc
    [
      ("format", `String "gamepilot-gifts/1"); ("gifts", `List [ `Assoc fields ]);
    ]

let refused name edits expectation : Table_test.case =
  {
    name;
    input = (fun () -> decoded "refused" (D.of_json (one_gift edits)));
    expectation;
  }

let refusal_cases =
  [
    refused "the base gift decodes" [] "xerneas-30th";
    refused "an unknown how"
      [ ("how", `String "mail") ]
      "refused: gifts.json: gifts[0].how is \"mail\", not code, internet or \
       home";
    refused "a code gift without its code"
      [ ("code", `Null) ]
      "refused: gifts.json: gift xerneas-30th: a code gift needs its code";
    refused "an internet gift with a code"
      [ ("how", `String "internet") ]
      "refused: gifts.json: gift xerneas-30th: only a code gift has a code";
    refused "a lower-case code"
      [ ("code", `String "celebrate30th") ]
      "refused: gifts.json: gift xerneas-30th: the code is upper-case letters \
       and digits";
    refused "a box slot without its HOME box"
      [ ("home_boxes", `Null) ]
      "refused: gifts.json: gifts[0].box_slot, home_boxes and home_order go \
       together";
    refused "slot 31"
      [ ("box_slot", `Assoc [ ("box", `Int 1); ("slot", `Int 31) ]) ]
      "refused: gifts.json: gift xerneas-30th: box is 1 or more, slot 1 to 30, \
       home_boxes some of 1 to 300";
    refused "HOME box 301"
      [ ("home_boxes", `List [ `Int 301 ]) ]
      "refused: gifts.json: gift xerneas-30th: box is 1 or more, slot 1 to 30, \
       home_boxes some of 1 to 300";
    refused "an unknown HOME order"
      [ ("home_order", `String "spiral") ]
      "refused: gifts.json: gifts[0].home_order is \"spiral\", not \
       left_to_right or right_to_left";
    refused "a source elsewhere"
      [ ("source", `String "https://example.com/x") ]
      "refused: gifts.json: gift xerneas-30th: the source is a Dittobase, \
       Nintendo Life or VGC page";
    refused "a bad day"
      [ ("expires", `String "2027-13-01") ]
      "refused: gifts.json: gifts[0].expires: \"2027-13-01\" is not a day \
       written YYYY-MM-DD";
    refused "an unknown field"
      [ ("region", `String "EU") ]
      "refused: gifts.json: gifts[0].region is not a field";
    refused "an id with capitals"
      [ ("id", `String "Xerneas") ]
      "refused: gifts.json: gift Xerneas: the id is 1 to 40 of a-z, 0-9 and -";
  ]

let twice_cases : Table_test.case list =
  let doubled =
    match one_gift [] with
    | `Assoc [ f; ("gifts", `List [ g ]) ] ->
        `Assoc [ f; ("gifts", `List [ g; g ]) ]
    | j -> j
  in
  [
    {
      name = "an id twice";
      input = (fun () -> decoded "refused" (D.of_json doubled));
      expectation = "refused: gifts.json: id xerneas-30th is given twice";
    };
  ]

let () =
  Table_test.run "gift_catalog"
    (shipped_cases @ date_cases @ refusal_cases @ twice_cases)
