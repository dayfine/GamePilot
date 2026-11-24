(* What the runner decides on a console without save states, from what it
   read: the start check after a reload (Start_check), the pre-flight of a save
   against the first checkpoint's plan (Preflight), and the room the Mail
   Glitch chain needs in the party (Party_room). Plans are mg-01..06's. *)

open Frlg_story
module P = Story.Postcondition_check
module F = Frlg_readers.Start_frame

let plan id =
  match Story.Plan_decode.load (id ^ ".plan.json") with
  | Ok p -> p
  | Error e -> failwith e

let chain =
  List.map plan
    [ "mg-01"; "mg-02"; "mg-03"; "mg-04"; "mg-05a"; "mg-05"; "mg-06" ]

let case name input expectation = { Case_table.name; input; expectation }

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

let party l = Some (Story.Plan.Party_in_order l)
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

let needs id before = Preflight.needs stocks ~before (plan id)

let observed ?party ?money ?(items = []) () =
  {
    P.nothing_read with
    party = Option.map (List.map Option.some) party;
    money;
    items;
  }

let preflight id before read =
  let rows = Preflight.compare (needs id before) read in
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

let same = Some { F.tiles = 150; changed = 3 }

(* The pre-flight's row for mg-02's Cut user. *)
let cut_row read =
  let before = Some (plan "mg-01").postconditions in
  Preflight.compare (needs "mg-02" before) read
  |> List.filter_map (fun (r : Preflight.row) ->
         if String.ends_with ~suffix:"(cut_tree)" r.need then
           Some
             (Printf.sprintf "%s: %s: %s" r.need r.read
                (match r.verdict with
                | Ok -> "ok"
                | Mismatch -> "MISMATCH"
                | Not_read -> "NOT READ"))
         else None)
  |> String.concat " | "

let preflight_cases =
  [
    case "preflight mg-01: Fly's user, the purchases' money and the place"
      (fun () ->
        preflight "mg-01" None
          {
            observed = observed ~party:[ "blastoise"; "pidgey" ] ~money:25014 ();
            place = same;
          })
      "pidgey in the party (fly): blastoise, pidgey: ok | money at least ¥4100 \
       (mart, buy_coins): ¥25014: ok | at the start, CeladonCity: 3 of 150 \
       tiles changed: ok => go";
    case "preflight mg-01: no Fly user and too little money stop"
      (fun () ->
        preflight "mg-01" None
          {
            observed = observed ~party:[ "blastoise" ] ~money:4000 ();
            place = same;
          })
      "pidgey in the party (fly): blastoise: MISMATCH | money at least ¥4100 \
       (mart, buy_coins): ¥4000: MISMATCH | at the start, CeladonCity: 3 of \
       150 tiles changed: ok => stop";
    case "preflight mg-01: no kept frame: the place is not read, which stops"
      (fun () ->
        preflight "mg-01" None
          {
            observed = observed ~party:[ "pidgey" ] ~money:25014 ();
            place = None;
          })
      "pidgey in the party (fly): pidgey: ok | money at least ¥4100 (mart, \
       buy_coins): ¥25014: ok | at the start, CeladonCity: no kept start frame \
       to compare: NOT READ => stop";
    case "preflight mg-02, mGBA: Rattata knows Cut"
      (fun () ->
        cut_row
          {
            observed =
              {
                (observed
                   ~party:[ "blastoise"; "rattata"; "oddish"; "pidgey"; "abra" ]
                   ())
                with
                knows =
                  [
                    ("rattata", [ "tackle"; "tail-whip"; "hyper-fang"; "cut" ]);
                  ];
              };
            place = same;
          })
      "rattata knows cut (cut_tree): rattata: tackle, tail-whip, hyper-fang, \
       cut: ok";
    case "preflight mg-02, console B: no Rattata, so no Cut user the plan names"
      (fun () ->
        cut_row
          {
            observed =
              observed
                ~party:[ "blastoise"; "pidgey"; "oddish"; "lapras"; "abra" ]
                ();
            place = same;
          })
      "rattata knows cut (cut_tree): not in the party: blastoise, pidgey, \
       oddish, lapras, abra: MISMATCH";
    case "preflight mg-03: what mg-02 promised, exactly"
      (fun () ->
        let before = Some (plan "mg-02").postconditions in
        String.concat "; "
          (List.map
             (fun (r : Preflight.row) -> r.need)
             (Preflight.compare (needs "mg-03" before)
                { observed = P.nothing_read; place = None })))
      "party includes blastoise, rattata, pidgey, abra, farfetchd; pidgey in \
       the party (fly); abra in the party (ingame_trade); rattata knows cut \
       (cut_tree); money ¥25014..¥25014; money at least ¥3550 (mart); at the \
       start, VermilionCity";
  ]

(* {1 Room in the party} *)

let member ?moves slot species level =
  { Story.Room_policy.slot; species; level = Some level; moves }

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

let need = Party_room.chain_need chain

let deposits party =
  match Party_room.deposits need party with
  | Ok [] -> "room enough"
  | Ok l -> "deposit " ^ String.concat ", " l
  | Error e -> "stop: " ^ e

let room_cases =
  [
    case "room: the chain brings Abra (mg-01) and Spearow (mg-02)"
      (fun () ->
        String.concat ", " (List.map (fun (s, id) -> s ^ " " ^ id) need.joins)
        ^ Printf.sprintf "; %d free" (Party_room.free_needed need))
      "abra mg-01, spearow mg-02; 2 free";
    case "room: the members the plans use or promise"
      (fun () -> String.concat ", " need.used)
      "blastoise, oddish, pidgey, rattata";
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
       its moves did not read; pidgey: the plans use it; oddish: the plans use \
       it; lapras: its moves did not read; magikarp: its moves did not read";
  ]

let room_row party =
  let r = Preflight.room need { observed = observed ~party (); place = None } in
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
      "2 free party slots (abra mg-01, spearow mg-02): 0 free; 2 to deposit, 0 \
       may go; kept: blastoise: the plans use it; eevee: its moves did not \
       read; pidgey: the plans use it; oddish: the plans use it; lapras: its \
       moves did not read; magikarp: its moves did not read: MISMATCH";
    case "preflight room: four members: ok"
      (fun () -> room_row (List.filteri (fun i _ -> i < 4) names))
      "2 free party slots (abra mg-01, spearow mg-02): 2 free: ok";
  ]

let () =
  Case_table.run "console start"
    (start_cases @ preflight_cases @ room_cases @ room_row_cases)
