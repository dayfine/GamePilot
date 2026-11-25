(* The Mail Glitch plans read as FireRed loads them (Plan_file: places
   expanded, then decoded): every one decodes, each one's outline, typed
   events, and the postconditions, retries and repeat its metadata promises. *)

let plan name =
  match Frlg_checkpoints.Plan_file.load name with
  | Ok plan -> plan
  | Error message -> failwith message

let plan_names =
  [
    "01-celadon-setup";
    "02-trade-farfetchd";
    "03-trade-mr-mime";
    "04-grind-farfetchd";
    "05-grind-mr-mime";
    "06-grind-return";
    "07-glitch-prep";
    "08-activate-and-verify";
  ]

let all_decode () =
  match
    List.filter_map
      (fun id ->
        Result.fold
          ~ok:(fun _ -> None)
          ~error:Option.some
          (Frlg_checkpoints.Plan_file.load (id ^ ".plan.json")))
      plan_names
  with
  | [] -> "all decode"
  | first :: _ -> first

let outline name = Pokemon_checkpoints.Plan_text.outline (plan name)
let event name id = Pokemon_checkpoints.Plan_text.event_named (plan name) id

let records : Table_test.case list =
  [
    {
      name = "every Mail Glitch plan";
      input = all_decode;
      expectation = "all decode";
    };
    {
      name = "01-celadon-setup outline";
      input = (fun () -> outline "01-celadon-setup.plan.json");
      expectation =
        "frlg 01-celadon-setup from CeladonCity (48, 12) south: 6 game_action, \
         7 route, 1 talk, 1 scene";
    };
    {
      name = "a place route, expanded: the lift ride FireRed adds";
      input = (fun () -> event "01-celadon-setup.plan.json" "to_4f_clerk.lift");
      expectation =
        {|to_4f_clerk.lift: [lift_floor] game_action {"from":"1F","to":"4F"} => CeladonCity_DepartmentStore_4F (6, 2) south|};
    };
    {
      name = "02-trade-farfetchd outline";
      input = (fun () -> outline "02-trade-farfetchd.plan.json");
      expectation =
        "frlg 02-trade-farfetchd from CeladonCity (39, 21) south: 7 route, 6 \
         game_action, 1 scene";
    };
    {
      name = "03-trade-mr-mime outline";
      input = (fun () -> outline "03-trade-mr-mime.plan.json");
      expectation =
        "frlg 03-trade-mr-mime from VermilionCity (19, 18) south: 5 \
         game_action, 5 route, 1 heal";
    };
    {
      name = "04-grind-farfetchd outline";
      input = (fun () -> outline "04-grind-farfetchd.plan.json");
      expectation =
        "frlg 04-grind-farfetchd from LavenderTown_PokemonCenter_1F (7, 4) \
         north: 2 route, 3 game_action, 1 heal";
    };
    {
      name = "05-grind-mr-mime outline: one grind round";
      input = (fun () -> outline "05-grind-mr-mime.plan.json");
      expectation =
        "frlg 05-grind-mr-mime from IndigoPlateau_PokemonCenter_1F (13, 12) \
         north: 1 game_action";
    };
    {
      name = "06-grind-return outline";
      input = (fun () -> outline "06-grind-return.plan.json");
      expectation =
        "frlg 06-grind-return from IndigoPlateau_PokemonCenter_1F (13, 12) \
         north: 2 route, 1 game_action";
    };
    {
      name = "07-glitch-prep outline";
      input = (fun () -> outline "07-glitch-prep.plan.json");
      expectation =
        "frlg 07-glitch-prep from LavenderTown (18, 7) south: 9 route, 12 \
         game_action, 1 scene";
    };
    {
      name = "08-activate-and-verify outline";
      input = (fun () -> outline "08-activate-and-verify.plan.json");
      expectation =
        "frlg 08-activate-and-verify from Route16 (30, 7) north: 18 \
         game_action, 3 route";
    };
    {
      name = "a route's typed target";
      input =
        (fun () -> event "02-trade-farfetchd.plan.json" "to_route16_cut_tree");
      expectation = "to_route16_cut_tree: [run] route to Route16 (41, 12) north";
    };
    {
      name = "a game action keeps its args as JSON, and its declared_after";
      input = (fun () -> event "02-trade-farfetchd.plan.json" "fly_vermilion");
      expectation =
        {|fly_vermilion: [fly] game_action {"town":"VermilionCity","species":"pidgey"} => VermilionCity (15, 7) south|};
    };
    {
      name =
        "01-celadon-setup promises the members the plans use (Abra among \
         them), 20 coins gained and $4,100 spent";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "01-celadon-setup.plan.json"));
      expectation =
        "party includes blastoise, pidgey, abra\n\
         coins gained 20\n\
         money spent 4100";
    };
    {
      name =
        "03-trade-mr-mime promises MIMIEN for Abra, 2 Revives and an Escape \
         Rope";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "03-trade-mr-mime.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 2\n\
         item escape-rope gained 1\n\
         money spent 3550";
    };
    {
      name = "04-grind-farfetchd promises Knock Off and one rope used";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "04-grind-farfetchd.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 0\n\
         item escape-rope used 1\n\
         money spent 0\n\
         farfetchd knows knock-off";
    };
    {
      name = "a grind round (05-grind-mr-mime) promises what holds on any save";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "05-grind-mr-mime.plan.json"));
      expectation =
        "position IndigoPlateau_PokemonCenter_1F (13, 12) north\n\
         party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0";
    };
    {
      name = "06-grind-return promises the grind's moves";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "06-grind-return.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0\n\
         farfetchd knows knock-off\n\
         mr-mime knows recycle\n\
         mr-mime at least Lv 33";
    };
    {
      name =
        "08-activate-and-verify promises MIMIEN in slot 1, where the \
         duplication gives, and Lea & Jed's prize less the mail";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "08-activate-and-verify.plan.json"));
      expectation =
        "party includes mr-mime, pidgey\n\
         mr-mime in slot 1\n\
         item antidote gained 0\n\
         item retro-mail gained 1\n\
         money spent -1224";
    };
    {
      name = "07-glitch-prep promises Blastoise's Leppa Berry and MIMIEN's mail";
      input =
        (fun () ->
          Pokemon_checkpoints.Plan_text.postconditions
            (plan "07-glitch-prep.plan.json"));
      expectation =
        "party includes pidgey\n\
         farfetchd in slot 1\n\
         blastoise in slot 2\n\
         mr-mime in slot 3\n\
         item antidote gained 2\n\
         item super-potion gained 3\n\
         item retro-mail used 1\n\
         money spent 2300\n\
         marks held_item, held_item, mail";
    };
  ]

let cases : Table_test.case list =
  let case name input expectation : Table_test.case =
    { name; input; expectation }
  in
  [
    case "08-activate-and-verify retries the battle's luck 3 times"
      (fun () ->
        string_of_int (plan "08-activate-and-verify.plan.json").retries)
      "3";
    case "05-grind-mr-mime repeats until MIMIEN is Lv 33 and knows Recycle"
      (fun () ->
        Pokemon_checkpoints.Plan_text.repeat (plan "05-grind-mr-mime.plan.json"))
      "at most 20 rounds, until:\nmr-mime knows recycle\nmr-mime at least Lv 33";
    case "05-grind-mr-mime retries each round twice"
      (fun () -> string_of_int (plan "05-grind-mr-mime.plan.json").retries)
      "2";
  ]

let () = Table_test.run "mail_glitch_plans" (records @ cases)
