(* The shared FireRed actions' pure parts: args read from plan JSON (the errors
   name the action and the field), the Mart's buys and quantity presses, the
   reckoned party, the Game Corner's batches, the bag's scrolling and names,
   and the spin's turns. *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }
let stocks = Result.get_ok (Mart_plan.load ())

let decode ?(options = Run_options.none) name json () =
  match
    Action_requests.decode ~options stocks name
      (Json_field.as_object "" (Yojson.Safe.from_string json))
  with
  | Ok r -> Action_requests.to_string r
  | Error c -> Pokemon_engine.Failure.cause_to_string c

let sweeper_options value =
  let decl : Run_options.declared list =
    [
      {
        key = "sweeper";
        value = Text;
        presence = Default "blastoise";
        doc = "";
      };
    ]
  in
  Result.get_ok (Run_options.check decl [ ("sweeper", value) ])

let decoding =
  [
    case "mart: Retro Mail at Celadon 4F"
      (decode "mart"
         {|{"map": "CeladonCity_DepartmentStore_4F", "items": [{"item": "retro-mail", "quantity": 2}]}|})
      "mart CeladonCity_DepartmentStore_4F: 2 retro-mail";
    case "mart: an item the Mart does not sell"
      (decode "mart"
         {|{"map": "LavenderTown_Mart", "items": [{"item": "retro-mail", "quantity": 2}]}|})
      "bad_args: mart: items[0].item retro-mail is not sold here.";
    case "mart: a quantity over 99"
      (decode "mart"
         {|{"map": "LavenderTown_Mart", "items": [{"item": "revive", "quantity": 100}], "budget": 5000}|})
      "bad_args: mart: items[0].quantity is 100, not 1-99.";
    case "mart: an unknown Mart"
      (decode "mart" {|{"map": "PalletTown", "items": []}|})
      "bad_args: mart: map PalletTown is no Mart we know the stock of.";
    case "give_bag_item to a species"
      (decode "give_bag_item" {|{"item": "retro-mail", "species": "mr-mime"}|})
      "give retro-mail to mr-mime";
    case "give_bag_item by role uses default species when no option is given"
      (decode "give_bag_item"
         {|{"item": "leppa-berry", "species": "blastoise", "role": "sweeper"}|})
      "give leppa-berry to blastoise";
    case "give_bag_item by role is overridden by --options sweeper"
      (decode
         ~options:(sweeper_options "charizard")
         "give_bag_item"
         {|{"item": "leppa-berry", "species": "blastoise", "role": "sweeper"}|})
      "give leppa-berry to charizard";
    case "give_bag_item without role ignores --options sweeper"
      (decode
         ~options:(sweeper_options "charizard")
         "give_bag_item" {|{"item": "retro-mail", "species": "mr-mime"}|})
      "give retro-mail to mr-mime";
    case "give_bag_item to a slot out of range"
      (decode "give_bag_item" {|{"item": "sitrus-berry", "target_slot": 7}|})
      "bad_args: give_bag_item: target_slot is 7, not a party slot (1-6).";
    case "give_bag_item with no recipient"
      (decode "give_bag_item" {|{"item": "retro-mail"}|})
      "bad_args: give_bag_item: needs species or target_slot.";
    case "use_item on the field"
      (decode "use_item" {|{"item": "escape-rope"}|})
      "use escape-rope";
    case "use_item on a slot"
      (decode "use_item" {|{"item": "revive", "target_slot": 2}|})
      "use revive on slot 2";
    case "party_swap by species"
      (decode "party_swap" {|{"species": "farfetchd", "target_slot": 1}|})
      "swap farfetchd to slot 1";
    case "party_swap by role uses default species when no option is given"
      (decode "party_swap"
         {|{"species": "blastoise", "role": "sweeper", "target_slot": 1}|})
      "swap blastoise to slot 1";
    case "party_swap by role is overridden by --options sweeper"
      (decode
         ~options:(sweeper_options "charizard")
         "party_swap"
         {|{"species": "blastoise", "role": "sweeper", "target_slot": 1}|})
      "swap charizard to slot 1";
    case "party_swap by role without species fails when option is unset"
      (decode "party_swap" {|{"role": "sweeper", "target_slot": 1}|})
      "bad_args: party_swap: role sweeper needs --options sweeper=SPECIES or \
       species.";
    case "party_swap by slots"
      (decode "party_swap" {|{"slot_a": 2, "slot_b": 5}|})
      "swap slots 2 and 5";
    case "party_swap missing its slot"
      (decode "party_swap" {|{"species": "farfetchd"}|})
      "bad_args: party_swap: target_slot is missing.";
    case "buy_coins" (decode "buy_coins" {|{"coins": 200}|}) "buy 200 coins";
    case "buy_coins not a multiple of 50"
      (decode "buy_coins" {|{"coins": 120}|})
      "bad_args: buy_coins: coins is 120, not a positive multiple of 50.";
    case "redeem_prize_mon out of range"
      (decode "redeem_prize_mon" {|{"slot": 5}|})
      "bad_args: redeem_prize_mon: slot is 5, not a prize row (0-4).";
    case "ingame_trade"
      (decode "ingame_trade" {|{"species": "spearow", "receive": "farfetchd"}|})
      "trade spearow for farfetchd";
    case "spin_for_encounter with its default"
      (decode "spin_for_encounter" "{}")
      "spin for an encounter, 25 batches at most";
    case "pc_deposit: species"
      (decode "pc_deposit" {|{"species": ["eevee", "magikarp"]}|})
      "deposit eevee, magikarp at the PC";
    case "pc_deposit: the member holding no Mail"
      (decode "pc_deposit" {|{"member": "holding_no_mail"}|})
      "deposit the member holding no Mail at the PC";
    case "pc_deposit: species and a role together"
      (decode "pc_deposit"
         {|{"member": "holding_no_mail", "species": ["mr-mime"]}|})
      "bad_args: pc_deposit: species and member: name the members or their \
       role, not both.";
    case "pc_deposit: a member role it does not know"
      (decode "pc_deposit" {|{"member": "the_lead"}|})
      "bad_args: pc_deposit: member is the_lead, not holding_no_mail.";
    case "cut_tree"
      (decode "cut_tree" {|{"direction": "north"}|})
      "cut the tree to the north";
    case "verify_mail_glitch"
      (decode "verify_mail_glitch" {|{"species": "mr-mime"}|})
      "verify the mail glitch on mr-mime";
    case "read_caught, logged only"
      (decode "read_caught" "{}")
      "read the species caught";
    case "read_caught with a floor"
      (decode "read_caught" {|{"at_least": 60}|})
      "read the species caught, at least 60";
    case "read_caught past the National Pokedex"
      (decode "read_caught" {|{"at_least": 400}|})
      "bad_args: read_caught: at_least is 400, not 0..386";
    case "an action FireRed does not have"
      (decode "switch_grind" "{}")
      "unknown_action: switch_grind";
  ]

let buys ?(options = Run_options.none) map items budget () =
  let stock = Option.get (Mart_plan.stock stocks map) in
  let lines =
    List.map (fun (i, q) -> { Mart_plan.line_item = i; quantity = q }) items
  in
  let plan = Mart_plan.apply_options options { map; lines; budget } in
  Mart_plan.buys_to_string (Mart_plan.buys stock plan)

let supplies_options pairs =
  let decl : Run_options.declared list =
    [
      {
        key = "retro-mail";
        value = Int_range (0, 999);
        presence = Default "100";
        doc = "";
      };
      {
        key = "super-repel";
        value = Int_range (0, 99);
        presence = Default "5";
        doc = "";
      };
    ]
  in
  Result.get_ok (Run_options.check decl pairs)

let presses q () =
  let right, up = Mart_plan.quantity_presses q in
  Printf.sprintf "right %d, up %d" right up

let mart =
  [
    case "mg-03's Lavender buys, no budget"
      (buys "LavenderTown_Mart" [ ("revive", 2); ("escape-rope", 1) ] None)
      "2 revive (row 2, $3000); 1 escape-rope (row 7, $550)";
    case "a budget cuts the first line and drops the second"
      (buys "LavenderTown_Mart"
         [ ("revive", 2); ("escape-rope", 1) ]
         (Some 2000))
      "1 revive (row 2, $1500)";
    case "options override retro-mail to 20 (collapses 50+50)"
      (buys
         ~options:(supplies_options [ ("retro-mail", "20") ])
         "CeladonCity_DepartmentStore_4F"
         [ ("retro-mail", 50); ("retro-mail", 50) ]
         None)
      "20 retro-mail (row 1, $1000)";
    case "options override retro-mail to 150 (splits 50+50+50)"
      (buys
         ~options:(supplies_options [ ("retro-mail", "150") ])
         "CeladonCity_DepartmentStore_4F"
         [ ("retro-mail", 50); ("retro-mail", 50) ]
         None)
      "50 retro-mail (row 1, $2500); 50 retro-mail (row 1, $2500); 50 \
       retro-mail (row 1, $2500)";
    case "options override super-repel to 0 (skips purchase)"
      (buys
         ~options:(supplies_options [ ("super-repel", "0") ])
         "LavenderTown_Mart"
         [ ("super-repel", 5) ]
         None)
      "nothing";
    case "quantity 1: no presses" (presses 1) "right 0, up 0";
    case "quantity 25: two tens, then four" (presses 25) "right 2, up 4";
    case "quantity 99" (presses 99) "right 9, up 8";
  ]

let party_text p = String.concat "," (Party_roster.to_list p)
let mg = Party_roster.of_string "blastoise, pidgey,abra, spearow"

let roster =
  [
    case "swap slots 1 and 4"
      (fun () -> party_text (Party_roster.swap mg 1 4))
      "spearow,pidgey,abra,blastoise";
    case "a trade replaces the member"
      (fun () -> party_text (Party_roster.replace mg ~slot:4 "farfetchd"))
      "blastoise,pidgey,abra,farfetchd";
    case "a species not in the party"
      (fun () ->
        match Party_roster.resolve mg (Species "mr-mime") with
        | Ok n -> string_of_int n
        | Error c -> Pokemon_engine.Failure.cause_to_string c)
      "not_in_party: mr-mime is not in the party (blastoise, pidgey, abra, \
       spearow)";
    case "a full party sends a prize to the PC"
      (fun () ->
        party_text
          (Party_roster.add (Party_roster.of_string "a,b,c,d,e,f") "abra"))
      "a,b,c,d,e,f";
  ]

let ints l = String.concat " " (List.map string_of_int l)
let names = [ "POTION"; "POKé BALL"; "RETRO MAIL"; "ESCAPE ROPE" ]
let opt = Option.value ~default:"none"

let others =
  [
    case "200 coins: four 50s"
      (fun () -> ints (Game_corner.coin_batches 200))
      "50 50 50 50";
    case "1100 coins: two 500s, two 50s"
      (fun () -> ints (Game_corner.coin_batches 1100))
      "500 500 50 50";
    case "bag taps before list rows 0, 5, 6 and 9 show"
      (fun () -> ints (List.map Bag_items.taps_to_reveal [ 0; 5; 6; 9 ]))
      "0 0 4 7";
    case "a slug names its bag name"
      (fun () -> opt (Bag_items.display_name names "retro-mail"))
      "RETRO MAIL";
    case "a slug with é"
      (fun () -> opt (Bag_items.display_name names "poke-ball"))
      "POKé BALL";
    case "a slug the pocket lacks"
      (fun () -> opt (Bag_items.display_name names "revive"))
      "none";
    case "spin: five turns clockwise from west"
      (fun () ->
        String.concat " "
          (List.map Grid_geometry.Direction.name
             (Spin_for_encounter.turns West 5)))
      "north east south west north";
  ]

let () = Table_test.run "action_requests" (decoding @ mart @ roster @ others)
