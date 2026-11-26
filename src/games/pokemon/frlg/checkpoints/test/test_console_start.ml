(* What the runner decides on a console without save states, from what it
   read: the start check after a reload (Start_check), the pre-flight of a save
   against the first checkpoint's plan (Preflight), and the room the Mail
   Glitch chain needs in the party (Party_room). Plans are 01-celadon-setup..08-activate-and-verify. *)

open Frlg_checkpoints
module P = Pokemon_engine.Postcondition_check
module F = Frlg_readers.Start_frame

let plan id =
  match Frlg_checkpoints.Plan_file.load (id ^ ".plan.json") with
  | Ok p -> p
  | Error e -> failwith e

let chain =
  List.map plan
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

let case name input expectation = { Table_test.name; input; expectation }

(* {1 The start check} *)

let frame ?(changed = 0) () =
  match
    F.of_json
      (`Assoc
         [
           ( "tiles",
             `List
               (List.init 150 (fun i ->
                    let v = if i < changed then 200. else 100. in
                    `List [ `Float v; `Float v; `Float v ])) );
         ])
  with
  | Ok f -> f
  | Error e -> failwith e

let party l = Some (Pokemon_engine.Postconditions.Party_in_order l)
let read l = Some (List.map Option.some l)

let start_check expected observed =
  let results = Start_check.check expected observed in
  String.concat " | " (List.map P.result_to_string results)
  ^ " => "
  ^ match Start_check.mismatches results with [] -> "start" | _ -> "stop"

let start_cases =
  let reference = Some (frame ()) in
  [
    case "start: the party and the place as kept: the run starts"
      (fun () ->
        start_check
          { party = party [ "blastoise"; "pidgey" ]; frame = reference }
          {
            party_read = read [ "blastoise"; "pidgey" ];
            frame_read = Some (frame ~changed:20 ());
          })
      "party: passed: blastoise, pidgey | place: passed: 20 of 150 tiles \
       changed => start";
    case "start: another place (over a quarter of the tiles changed) stops"
      (fun () ->
        start_check
          { party = None; frame = reference }
          { party_read = None; frame_read = Some (frame ~changed:40 ()) })
      "place: failed: 40 of 150 tiles changed => stop";
    case "start: another party stops"
      (fun () ->
        start_check
          { party = party [ "blastoise"; "pidgey" ]; frame = reference }
          {
            party_read = read [ "pidgey"; "blastoise" ];
            frame_read = reference;
          })
      "party: failed: expected blastoise, pidgey, read pidgey, blastoise | \
       place: passed: 0 of 150 tiles changed => stop";
    case "start: no frame kept yet and a party not read: logged, the run starts"
      (fun () ->
        start_check
          { party = party [ "blastoise" ]; frame = None }
          { party_read = None; frame_read = Some (frame ()) })
      "party: not checked: the game can't read it | place: not checked: no \
       start frame kept yet => start";
  ]

(* {1 The pre-flight} *)

let stocks =
  match Frlg_actions.Mart_plan.load () with Ok s -> s | Error e -> failwith e

let needs id before =
  match Preflight.needs stocks ~before (plan id) with
  | Ok needs -> needs
  | Error e -> failwith e

let observed ?party ?money ?(items = []) () =
  {
    P.nothing_read with
    party = Option.map (List.map Option.some) party;
    money;
    items;
  }

let rows_text needs read =
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

let preflight id before read = rows_text (needs id before) read
let same = Some { F.tiles = 150; changed = 3 }

(* The Trainer Card's front with the first [n] badges and no star. *)
let badges n : Frlg_readers.Trainer_card_front.t option =
  Some { badges = List.init 8 (fun i -> i < n); stars = 0 }

let summary slot species moves : Room_policy.member =
  { slot; species; level = Some 30; moves = Some moves }

(* The pre-flight's row for 02-trade-farfetchd's Cut user. *)
let cut_row read =
  let before =
    Some
      (Pokemon_engine.Postconditions.stated
         (plan "01-celadon-setup").postconditions)
  in
  Preflight.compare (needs "02-trade-farfetchd" before) read
  |> List.filter_map (fun (r : Preflight.row) ->
         if String.starts_with ~prefix:"a member knows cut" r.need then
           Some
             (Printf.sprintf "%s: %s: %s" r.need r.read
                (match r.verdict with
                | Ok -> "ok"
                | Mismatch -> "MISMATCH"
                | Not_read -> "NOT READ"))
         else None)
  |> String.concat " | "

(* Each species' moves, for the Fly row: Pidgey knows Fly. *)
let members species =
  Some
    (List.mapi
       (fun i s ->
         summary (i + 1) s
           (if s = "pidgey" then [ "fly"; "gust" ] else [ "surf" ]))
       species)

let preflight_cases =
  [
    case
      "preflight 01-celadon-setup: Fly's user, the purchases' money and the \
       place"
      (fun () ->
        preflight "01-celadon-setup" None
          {
            observed = observed ~party:[ "blastoise"; "pidgey" ] ~money:25014 ();
            place = same;
            card = badges 8;
            members = members [ "blastoise"; "pidgey" ];
          })
      "a member knows fly (fly): pidgey knows fly: ok | the thunder badge \
       (fly): 8 badges (boulder, cascade, thunder, rainbow, soul, marsh, \
       volcano, earth), no star: ok | money at least ¥4100 (mart, buy_coins): \
       ¥25014: ok | at the start, anywhere outdoors where Fly works: not read: \
       the first Fly checks it: ok => go";
    case
      "preflight 01-celadon-setup: no Fly user, no Thunder Badge and too \
       little money stop"
      (fun () ->
        preflight "01-celadon-setup" None
          {
            observed = observed ~party:[ "blastoise" ] ~money:4000 ();
            place = same;
            card = badges 2;
            members = members [ "blastoise" ];
          })
      "a member knows fly (fly): no member knows fly: MISMATCH | the thunder \
       badge (fly): 2 badges (boulder, cascade), no star; missing thunder: \
       MISMATCH | money at least ¥4100 (mart, buy_coins): ¥4000: MISMATCH | at \
       the start, anywhere outdoors where Fly works: not read: the first Fly \
       checks it: ok => stop";
    case
      "preflight 02-trade-farfetchd: no kept frame: the place is not read, \
       which stops"
      (fun () ->
        Preflight.compare
          (needs "02-trade-farfetchd" None)
          {
            observed = observed ~party:[ "rattata" ] ();
            place = None;
            card = None;
            members = None;
          }
        |> List.filter_map (fun (r : Preflight.row) ->
               if String.starts_with ~prefix:"at the start" r.need then
                 Some (r.need ^ ": " ^ r.read)
               else None)
        |> String.concat " | ")
      "at the start, CeladonCity: no kept start frame to compare";
    case
      "preflight tt-01, console B: slot 1 is targeted by slot (no hardcoded \
       species); its Retro Mail and Super Repel come from su-01"
      (fun () ->
        preflight "tt-01" None
          {
            observed =
              observed
                ~party:[ "mr-mime"; "blastoise"; "pidgey" ]
                ~money:20476
                ~items:[ ("super-repel", 2); ("retro-mail", 100) ]
                ();
            place = same;
            card = badges 8;
            members = members [ "mr-mime"; "blastoise"; "pidgey" ];
          })
      "a member knows fly (fly): pidgey knows fly: ok | the thunder badge \
       (fly): 8 badges (boulder, cascade, thunder, rainbow, soul, marsh, \
       volcano, earth), no star: ok | super-repel at least x1 (use_item): \
       super-repel x2: ok | retro-mail at least x99 (duplicate_item): \
       retro-mail x100: ok | at the start, anywhere outdoors where Fly works: \
       not read: the first Fly checks it: ok => go";
    case "preflight 02-trade-farfetchd, mGBA: some member knows Cut (Rattata)"
      (fun () ->
        cut_row
          {
            observed = observed ~party:[ "blastoise"; "rattata" ] ();
            place = same;
            card = None;
            members =
              Some
                [
                  summary 1 "blastoise" [ "surf"; "bite" ];
                  summary 2 "rattata" [ "tackle"; "hyper-fang"; "cut" ];
                ];
          })
      "a member knows cut (cut_tree): rattata knows cut: ok";
    case "preflight 02-trade-farfetchd, console B: no Rattata, Oddish knows Cut"
      (fun () ->
        cut_row
          {
            observed = observed ~party:[ "blastoise"; "oddish" ] ();
            place = same;
            card = None;
            members =
              Some
                [
                  summary 1 "blastoise" [ "surf"; "strength" ];
                  summary 2 "oddish" [ "cut"; "absorb" ];
                ];
          })
      "a member knows cut (cut_tree): oddish knows cut: ok";
    case "preflight 02-trade-farfetchd: nobody knows Cut"
      (fun () ->
        cut_row
          {
            observed = observed ~party:[ "blastoise" ] ();
            place = same;
            card = None;
            members = Some [ summary 1 "blastoise" [ "surf" ] ];
          })
      "a member knows cut (cut_tree): no member knows cut: MISMATCH";
    case
      "preflight 02-trade-farfetchd: Cut outside battle needs the Cascade Badge"
      (fun () ->
        Preflight.compare
          (needs "02-trade-farfetchd" None)
          {
            observed = observed ~party:[ "rattata" ] ();
            place = same;
            card = badges 1;
            members = None;
          }
        |> List.filter_map (fun (r : Preflight.row) ->
               if String.ends_with ~suffix:"badge (cut_tree)" r.need then
                 Some (r.need ^ ": " ^ r.read)
               else None)
        |> String.concat " | ")
      "the cascade badge (cut_tree): 1 badge (boulder), no star; missing \
       cascade";
    case
      "preflight 03-trade-mr-mime: what 02-trade-farfetchd promised, exactly \
       (its money spent is no start need)"
      (fun () ->
        let before =
          Some
            (Pokemon_engine.Postconditions.stated
               (plan "02-trade-farfetchd").postconditions)
        in
        String.concat "; "
          (List.map
             (fun (r : Preflight.row) -> r.need)
             (Preflight.compare
                (needs "03-trade-mr-mime" before)
                {
                  observed = P.nothing_read;
                  place = None;
                  members = None;
                  card = None;
                })))
      "party includes blastoise, abra, farfetchd; abra in the party \
       (ingame_trade); a member knows fly (fly); a member knows cut \
       (cut_tree); the thunder badge (fly); the cascade badge (cut_tree); \
       money at least ¥3550 (mart); at the start, VermilionCity";
    case
      "preflight 04-grind-farfetchd: 03-trade-mr-mime's Revives and Escape \
       Rope gained are no start need (console B held 5 ropes, not mGBA's 3); \
       its own rope is"
      (fun () ->
        let before =
          Some
            (Pokemon_engine.Postconditions.stated
               (plan "03-trade-mr-mime").postconditions)
        in
        String.concat "; "
          (List.map
             (fun (r : Preflight.row) -> r.need)
             (Preflight.compare
                (needs "04-grind-farfetchd" before)
                {
                  observed = P.nothing_read;
                  place = None;
                  members = None;
                  card = None;
                })))
      "party includes blastoise, mr-mime, farfetchd; farfetchd in the party \
       (grind); blastoise in the party (grind); a member knows fly (fly); the \
       thunder badge (fly); escape-rope at least x1 (use_item); at the start, \
       LavenderTown_PokemonCenter_1F";
    case
      "preflight 05-grind-mr-mime (a grind round, resumed from any round's \
       save): what 04-grind-farfetchd promised, MIMIEN and Blastoise, at the \
       Indigo nurse"
      (fun () ->
        let before =
          Some
            (Pokemon_engine.Postconditions.stated
               (plan "04-grind-farfetchd").postconditions)
        in
        String.concat "; "
          (List.map
             (fun (r : Preflight.row) -> r.need)
             (Preflight.compare
                (needs "05-grind-mr-mime" before)
                {
                  observed = P.nothing_read;
                  place = None;
                  members = None;
                  card = None;
                })))
      "party includes blastoise, mr-mime, farfetchd; mr-mime in the party \
       (grind); blastoise in the party (grind); at the start, \
       IndigoPlateau_PokemonCenter_1F";
    case
      "preflight 07-glitch-prep: the Leppa Berry it picks up on Route 8 is no \
       start need for its give_bag_item (console B, 2026-11-24)"
      (fun () ->
        let before =
          Some
            (Pokemon_engine.Postconditions.stated
               (plan "06-grind-return").postconditions)
        in
        String.concat "; "
          (List.map
             (fun (r : Preflight.row) -> r.need)
             (Preflight.compare
                (needs "07-glitch-prep" before)
                {
                  observed = P.nothing_read;
                  place = None;
                  members = None;
                  card = None;
                })))
      "party includes blastoise, mr-mime, farfetchd; blastoise in the party \
       (party_swap); farfetchd in the party (party_swap); mr-mime in the party \
       (party_swap); a member knows cut (cut_tree); a member knows fly (fly); \
       the cascade badge (cut_tree); the thunder badge (fly); money at least \
       ¥2300 (mart); retro-mail at least x1 (give_bag_item); at the start, \
       LavenderTown";
  ]

(* {1 Room in the party} *)

let member ?moves slot species level =
  { Room_policy.slot; species; level = Some level; moves }

(* Console B's save on 2026-11-23: Pallet Town, after the Hall of Fame. The
   moves are what a plain run of FireRed would have them know; a real run
   reads them. *)
let console_b =
  [
    member 1 "blastoise" 59 ~moves:[ "surf"; "strength"; "blizzard"; "bite" ];
    member 2 "eevee" 25 ~moves:[ "tackle"; "tail-whip"; "bite"; "quick-attack" ];
    member 3 "pidgey" 24 ~moves:[ "fly"; "gust"; "quick-attack"; "sand-attack" ];
    member 4 "oddish" 12 ~moves:[ "cut"; "absorb"; "poison-powder"; "acid" ];
    member 5 "lapras" 25 ~moves:[ "surf"; "sing"; "mist"; "body-slam" ];
    member 6 "magikarp" 5 ~moves:[ "splash" ];
  ]

let chain_need plans = Result.get_ok (Party_room.chain_need plans)
let need = chain_need chain

let deposits party =
  match Party_room.deposits need party with
  | Ok [] -> "room enough"
  | Ok l -> "deposit " ^ String.concat ", " l
  | Error e -> "stop: " ^ e

(* A plan that stores two members at a PC: [pc_deposit]'s ["species"] is a
   list, and both members are used. *)
let deposit_plan =
  match
    Plan_file.decode ~source:"deposit"
      (Yojson.Safe.from_string
         {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
            "checkpoint": {"id": "deposit", "title": "Two members to the PC",
              "start": {"map": "Route4_PokemonCenter_1F", "tiles": [[11, 2]],
                        "facing": "north"},
              "events": [{"id": "deposit", "kind": "game_action",
                          "action": "pc_deposit",
                          "args": {"species": ["mr-mime", "abra"]}}]},
            "execution": {"menu": "full"}}|})
  with
  | Ok p -> p
  | Error e -> failwith e

let room_cases =
  [
    case "room: pc_deposit's species list: each member is used"
      (fun () -> String.concat ", " (chain_need [ deposit_plan ]).used)
      "abra, mr-mime";
    case "room: deposit before a catch makes its own room: 0 free needed"
      (fun () ->
        let catch_plan =
          match
            Plan_file.decode ~source:"catch"
              (Yojson.Safe.from_string
                 {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
                    "checkpoint": {"id": "catch", "title": "Catch one",
                      "events": [
                        {"id": "c", "kind": "game_action", "action": "wild_rng",
                         "args": {"species": "voltorb"}},
                        {"id": "d", "kind": "game_action", "action": "pc_deposit",
                         "args": {"species": ["voltorb"]}}]},
                    "execution": {"menu": "full"}}|})
          with
          | Ok p -> p
          | Error e -> failwith e
        in
        Printf.sprintf "with deposit=%d; two catches=%d"
          (Party_room.free_needed (chain_need [ deposit_plan; catch_plan ]))
          (Party_room.free_needed (chain_need [ catch_plan; catch_plan ])))
      "with deposit=0; two catches=1";
    case
      "room: the chain brings Abra (01-celadon-setup) and Spearow \
       (02-trade-farfetchd)"
      (fun () ->
        String.concat ", " (List.map (fun (s, id) -> s ^ " " ^ id) need.joins)
        ^ Printf.sprintf "; %d free" (Party_room.free_needed need))
      "abra 01-celadon-setup, spearow 02-trade-farfetchd; 2 free";
    case "room: the members the plans use or promise"
      (fun () -> String.concat ", " need.used)
      "blastoise";
    case
      "room: console B's full party: the lowest level that knows no field move \
       and is not used, twice"
      (fun () -> deposits console_b)
      "deposit eevee, magikarp";
    case "room: four members: room enough"
      (fun () -> deposits (List.filteri (fun i _ -> i < 4) console_b))
      "room enough";
    case "room: moves not read: those members stay"
      (fun () ->
        deposits
          (List.map
             (fun (m : Party_room.member) -> { m with moves = None })
             console_b))
      "stop: 2 to deposit, 0 may go; kept: blastoise: the plans use it; eevee: \
       its moves did not read; pidgey: its moves did not read; oddish: its \
       moves did not read; lapras: its moves did not read; magikarp: its moves \
       did not read";
  ]

let room_row party =
  let r =
    Preflight.room need
      {
        observed = observed ~party ();
        place = None;
        members = None;
        card = None;
      }
  in
  Printf.sprintf "%s: %s: %s" r.need r.read
    (match r.verdict with
    | Ok -> "ok"
    | Mismatch -> "MISMATCH"
    | Not_read -> "NOT READ")

let room_row_cases =
  let names = List.map (fun (m : Party_room.member) -> m.species) console_b in
  [
    case "preflight room: console B's full party: stop, moves not read here"
      (fun () -> room_row names)
      "2 free party slots (abra 01-celadon-setup, spearow 02-trade-farfetchd): \
       0 free; 2 to deposit, 0 may go; kept: blastoise: the plans use it; \
       eevee: its moves did not read; pidgey: its moves did not read; oddish: \
       its moves did not read; lapras: its moves did not read; magikarp: its \
       moves did not read: MISMATCH";
    case "preflight room: four members: ok"
      (fun () -> room_row (List.filteri (fun i _ -> i < 4) names))
      "2 free party slots (abra 01-celadon-setup, spearow 02-trade-farfetchd): \
       2 free: ok";
  ]

(* A plan that stores a member at a PC, by these args. *)
let deposit_plan_of args =
  let json =
    Printf.sprintf
      {|{"format": "gamepilot-checkpoint/1", "game": "frlg",
       "execution": {"menu": "full"},
       "checkpoint": {"id": "deposit", "title": "Store a member",
         "events": [{"id": "deposit", "kind": "game_action",
           "action": "pc_deposit", "args": %s,
           "why": "Room for the forest's catches."}]}}|}
      args
  in
  match Plan_file.decode ~source:"deposit" (Yojson.Safe.from_string json) with
  | Ok p -> p
  | Error e -> failwith e

(* Farfetch'd stored at Pewter's PC, as 09-viridian-forest's deposit did (mGBA,
   2026-11-25), with Farfetch'd holding Retro Mail. *)
let farfetchd_deposit_plan = deposit_plan_of {|{"species": ["farfetchd"]}|}

(* The member holding no Mail stored, as wild_rng's 01-route10-grass does. *)
let no_mail_deposit_plan = deposit_plan_of {|{"member": "holding_no_mail"}|}

let deposit_preflight ?(plan = farfetchd_deposit_plan) marks =
  let read : Preflight.read =
    {
      observed =
        {
          (observed ~party:[ "blastoise"; "mr-mime"; "farfetchd" ] ()) with
          marks;
        };
      place = None;
      members = None;
      card = None;
    }
  in
  match Preflight.needs stocks ~before:None plan with
  | Error e -> "error: " ^ e
  | Ok needs -> rows_text needs read

let deposit_cases =
  [
    case "preflight pc_deposit: the member stored holds Retro Mail: stop"
      (fun () -> deposit_preflight (Some [ "held_item"; "none"; "mail" ]))
      "farfetchd in the party (pc_deposit): blastoise, mr-mime, farfetchd: ok \
       | farfetchd holds no Mail (pc_deposit): farfetchd in slot 3: mail: \
       MISMATCH => stop";
    case "preflight pc_deposit: it holds an item, not Mail: go"
      (fun () -> deposit_preflight (Some [ "mail"; "none"; "held_item" ]))
      "farfetchd in the party (pc_deposit): blastoise, mr-mime, farfetchd: ok \
       | farfetchd holds no Mail (pc_deposit): farfetchd in slot 3: held_item: \
       ok => go";
    case "preflight pc_deposit: the marks not read: stop"
      (fun () -> deposit_preflight None)
      "farfetchd in the party (pc_deposit): blastoise, mr-mime, farfetchd: ok \
       | farfetchd holds no Mail (pc_deposit): not read: NOT READ => stop";
    case "preflight pc_deposit: the marks are read for it"
      (fun () ->
        match Preflight.needs stocks ~before:None farfetchd_deposit_plan with
        | Error e -> "error: " ^ e
        | Ok needs ->
            Option.fold ~none:"none"
              ~some:(fun _ -> "read")
              (Preflight.to_read needs).marks)
      "read";
    case "preflight pc_deposit by role: a member holds no Mail: go"
      (fun () ->
        deposit_preflight ~plan:no_mail_deposit_plan
          (Some [ "held_item"; "mail"; "mail" ]))
      "a member holds no Mail (pc_deposit): slot 1 holds no Mail: ok => go";
    case "preflight pc_deposit by role: every member holds Mail: stop"
      (fun () ->
        deposit_preflight ~plan:no_mail_deposit_plan
          (Some [ "mail"; "mail"; "mail" ]))
      "a member holds no Mail (pc_deposit): every member holds Mail: MISMATCH \
       => stop";
    case "preflight pc_deposit by role: no species is used"
      (fun () -> String.concat ", " (chain_need [ no_mail_deposit_plan ]).used)
      "";
  ]

let () =
  Table_test.run "console start"
    (start_cases @ preflight_cases @ deposit_cases @ room_cases @ room_row_cases)
