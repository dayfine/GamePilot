(* The Mail Glitch plans read as FireRed loads them (Plan_file: places
   expanded, then decoded): every one decodes, each one's outline, typed
   events, and the postconditions, retries and repeat its metadata promises. *)

let plan name =
  match Frlg_checkpoints.Plan_file.load name with
  | Ok plan -> plan
  | Error message -> failwith message

let plan_names =
  [
    "mg-01";
    "mg-02";
    "mg-03";
    "mg-04a";
    "mg-04b";
    "mg-04c";
    "mg-05a";
    "mg-05";
    "mg-06";
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

let outline name = Plan_text.outline (plan name)
let event name id = Plan_text.event_named (plan name) id

let records : Table_test.case list =
  [
    {
      name = "every Mail Glitch plan";
      input = all_decode;
      expectation = "all decode";
    };
    {
      name = "mg-01 outline";
      input = (fun () -> outline "mg-01.plan.json");
      expectation =
        "frlg mg-01 from CeladonCity (48, 12) south: 6 game_action, 7 route, 1 \
         talk, 1 scene";
    };
    {
      name = "a place route, expanded: the lift ride FireRed adds";
      input = (fun () -> event "mg-01.plan.json" "to_4f_clerk.lift");
      expectation =
        {|to_4f_clerk.lift: [lift_floor] game_action {"from":"1F","to":"4F"} => CeladonCity_DepartmentStore_4F (6, 2) south|};
    };
    {
      name = "mg-02 outline";
      input = (fun () -> outline "mg-02.plan.json");
      expectation =
        "frlg mg-02 from CeladonCity (39, 21) south: 7 route, 6 game_action, 1 \
         scene";
    };
    {
      name = "mg-03 outline";
      input = (fun () -> outline "mg-03.plan.json");
      expectation =
        "frlg mg-03 from VermilionCity (19, 18) south: 5 game_action, 5 route, \
         1 heal";
    };
    {
      name = "mg-04a outline";
      input = (fun () -> outline "mg-04a.plan.json");
      expectation =
        "frlg mg-04a from LavenderTown_PokemonCenter_1F (7, 4) north: 2 route, \
         3 game_action, 1 heal";
    };
    {
      name = "mg-04b outline: one grind round";
      input = (fun () -> outline "mg-04b.plan.json");
      expectation =
        "frlg mg-04b from IndigoPlateau_PokemonCenter_1F (13, 12) north: 1 \
         game_action";
    };
    {
      name = "mg-04c outline";
      input = (fun () -> outline "mg-04c.plan.json");
      expectation =
        "frlg mg-04c from IndigoPlateau_PokemonCenter_1F (13, 12) north: 2 \
         route, 1 game_action";
    };
    {
      name = "mg-05a outline";
      input = (fun () -> outline "mg-05a.plan.json");
      expectation =
        "frlg mg-05a from LavenderTown (18, 7) south: 9 route, 12 game_action, \
         1 scene";
    };
    {
      name = "mg-05 outline";
      input = (fun () -> outline "mg-05.plan.json");
      expectation = "frlg mg-05 from Route16 (30, 7) north: 2 game_action";
    };
    {
      name = "a route's typed target";
      input = (fun () -> event "mg-02.plan.json" "to_route16_cut_tree");
      expectation = "to_route16_cut_tree: [run] route to Route16 (41, 12) north";
    };
    {
      name = "a game action keeps its args as JSON, and its declared_after";
      input = (fun () -> event "mg-02.plan.json" "fly_vermilion");
      expectation =
        {|fly_vermilion: [fly] game_action {"town":"VermilionCity","species":"pidgey"} => VermilionCity (15, 7) south|};
    };
    {
      name =
        "mg-01 promises the members the plans use (Abra among them), 20 coins \
         gained and $4,100 spent";
      input = (fun () -> Plan_text.postconditions (plan "mg-01.plan.json"));
      expectation =
        "party includes blastoise, pidgey, abra\n\
         coins gained 20\n\
         money spent 4100";
    };
    {
      name = "mg-05 promises MIMIEN, Pidgey and slots 1-3's marks";
      input = (fun () -> Plan_text.postconditions (plan "mg-05.plan.json"));
      expectation =
        "party includes mr-mime, pidgey\nmarks held_item, none, held_item";
    };
    {
      name = "mg-03 promises MIMIEN for Abra, 2 Revives and an Escape Rope";
      input = (fun () -> Plan_text.postconditions (plan "mg-03.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 2\n\
         item escape-rope gained 1\n\
         money spent 3550";
    };
    {
      name = "mg-04a promises Knock Off and one rope used";
      input = (fun () -> Plan_text.postconditions (plan "mg-04a.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         item revive gained 0\n\
         item escape-rope used 1\n\
         money spent 0\n\
         farfetchd knows knock-off";
    };
    {
      name = "a grind round (mg-04b) promises what holds on any save";
      input = (fun () -> Plan_text.postconditions (plan "mg-04b.plan.json"));
      expectation =
        "position IndigoPlateau_PokemonCenter_1F (13, 12) north\n\
         party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0";
    };
    {
      name = "mg-04c promises the grind's moves";
      input = (fun () -> Plan_text.postconditions (plan "mg-04c.plan.json"));
      expectation =
        "party includes blastoise, pidgey, mr-mime, farfetchd\n\
         money spent 0\n\
         farfetchd knows knock-off\n\
         mr-mime knows recycle\n\
         mr-mime at least Lv 33";
    };
    {
      name = "mg-06 promises MIMIEN in slot 1, where the duplication gives";
      input = (fun () -> Plan_text.postconditions (plan "mg-06.plan.json"));
      expectation =
        "party includes pidgey\n\
         mr-mime in slot 1\n\
         item antidote gained 0\n\
         item retro-mail gained 1\n\
         money spent 400";
    };
    {
      name = "mg-05a promises Blastoise's Leppa Berry and MIMIEN's mail";
      input = (fun () -> Plan_text.postconditions (plan "mg-05a.plan.json"));
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
    case "mg-05 retries the battle's luck 3 times"
      (fun () -> string_of_int (plan "mg-05.plan.json").retries)
      "3";
    case "mg-04b repeats until MIMIEN is Lv 33 and knows Recycle"
      (fun () -> Plan_text.repeat (plan "mg-04b.plan.json"))
      "at most 20 rounds, until:\nmr-mime knows recycle\nmr-mime at least Lv 33";
    case "mg-04b retries each round twice"
      (fun () -> string_of_int (plan "mg-04b.plan.json").retries)
      "2";
  ]

let () = Table_test.run "mail_glitch_plans" (records @ cases)
