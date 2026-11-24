(* The rule table for each kind of settle, and Settle.run on a scripted
   screen: what it presses, when it ends and how it fails. Ported from the
   fork's Pokemon_Settle_Tests. *)

open Screen_state

let describe_rule (r : Settle.rule) =
  Printf.sprintf "warp=%b quiet=%dms calm=%dms still=%s look=%dms cap=%dms"
    r.judge.warp r.judge.quiet_ms r.judge.calm_ms
    (match r.judge.still with
    | Screen -> "screen still"
    | Player -> "player still")
    r.look_every_ms r.cap_ms

let rule_case name kind expectation =
  {
    Table_test.name;
    input = (fun () -> describe_rule (Settle.rule kind));
    expectation;
  }

let () =
  Table_test.run "Settle.rule"
    [
      rule_case "a talk waits out 5 s of quiet" Talk
        "warp=false quiet=5000ms calm=15000ms still=screen still look=1200ms \
         cap=120000ms";
      rule_case "after a warp, the fade or banner comes first" After_warp
        "warp=true quiet=5000ms calm=15000ms still=screen still look=1200ms \
         cap=120000ms";
      (* Wait 1 s of the player still after a door fade-in (lab-B
         2026-11-10). *)
      rule_case "a door waits 1 s of the player still, looking often" Door
        "warp=false quiet=1000ms calm=2500ms still=player still look=200ms \
         cap=120000ms";
      rule_case "a closed menu waits 0.5 s of quiet, looking often" Menu_closed
        "warp=false quiet=500ms calm=2500ms still=screen still look=300ms \
         cap=15000ms";
    ]

let quiet =
  {
    Facts.none with
    free_control = true;
    screen_still = true;
    player_still = true;
  }

let box = { Facts.none with dialog = true; screen_still = true }

(* The overworld with someone walking past: the screen moves, the player
   does not. *)
let people_walking =
  { Facts.none with free_control = true; player_still = true }

(* A black frame as BDSP's eyes see it: no box, so "overworld", and still. *)
let faded = { quiet with fade = Fade.Black }
let battle = { Facts.none with battle = true }
let repeat look n = List.init n (fun _ -> look)

let ending_text = function
  | Settle.Quiet _ -> "quiet"
  | Battle _ -> "battle"
  | Timed_out why -> "timed out: " ^ why

(* Each look takes the script's next facts, then its last for good. *)
let next_of script =
  let rest = ref script in
  fun () ->
    match !rest with
    | [ last ] -> last
    | x :: tail ->
        rest := tail;
        x
    | [] -> invalid_arg "empty script"

let flee_ms = 5000.

(* The screen a pressing game sees, a look per press. Each press and each
   fled battle moves the clock on. The text is the ending, then the presses:
   N for the talk's button, B for B, F for a flee. *)
let run_pressing rule ?(flee = true) script =
  let now = ref 0. in
  let presses = Buffer.create 16 in
  let next = next_of script in
  let io : Settle.io =
    {
      look = (fun () -> { facts = next (); at_ms = !now; since_ms = None });
      press =
        (fun p ~wait_ms ->
          Buffer.add_char presses (match p with Next -> 'N' | B -> 'B');
          now := !now +. float_of_int wait_ms;
          None);
      flee_battle =
        (fun () ->
          Buffer.add_char presses 'F';
          now := !now +. flee_ms;
          flee);
      log = ignore;
    }
  in
  let ending = Settle.run rule ~label:"Step" io in
  Printf.sprintf "%s; presses %s" (ending_text ending) (Buffer.contents presses)

let run_case name ?flee rule script expectation =
  {
    Table_test.name;
    input = (fun () -> run_pressing rule ?flee script);
    expectation;
  }

let talk = Settle.rule Talk
let door = Settle.rule Door

let before_battle =
  { talk with judge = { talk.judge with end_on_quiet = false } }

let short = { talk with look_every_ms = 1000; cap_ms = 3000 }

let () =
  Table_test.run "Settle.run"
    [
      run_case "a talk presses B while quiet, until 5 s of it" talk [ quiet ]
        "quiet; presses BBBBB";
      run_case "a box is answered with the talk's button" talk
        (repeat box 2 @ [ quiet ])
        "quiet; presses NNBBBBB";
      run_case "a door's settle ends 1 s after the fade is back up" door
        (repeat faded 3 @ [ quiet ])
        "quiet; presses BBBBBBBB";
      run_case "people walking about do not hold a door's settle up" door
        [ people_walking ] "quiet; presses BBBBB";
      run_case
        "someone walking about the whole time does not hold a closed menu's \
         settle up (calm)"
        (Settle.rule Menu_closed) [ people_walking ] "quiet; presses BBBBBBBBB";
      run_case "a wild battle is fled and the settle goes on" door
        [ quiet; battle; quiet ] "quiet; presses BFBBBBB";
      run_case "a battle not fled ends it" ~flee:false before_battle
        (repeat box 2 @ [ battle ])
        "battle; presses NNF";
      run_case "no fade or banner by the cap is a map mismatch"
        { short with judge = { short.judge with warp = true } }
        [ quiet ]
        "timed out: Step: no fade or banner within 3 s, so we are not where \
         the step goes (map mismatch).; presses BBB";
      run_case "no quiet overworld by the cap" short [ box ]
        "timed out: Step: not back on a quiet overworld within 3 s.; presses \
         NNN";
      run_case "no battle by the cap after a trainer's talk"
        { short with judge = { short.judge with end_on_quiet = false } }
        [ quiet ]
        "timed out: Step: no battle within 3 s of the talk.; presses BBB";
    ]

(* The screen a game that only watches sees: each look watches
   [look_every_ms] and moves the clock on by it; presses do nothing. A
   script entry is the facts and how long they had shown unchanged when the
   look ended, if known. The text is the ending, the looks and the flees. *)
let run_watching (rule : Settle.rule) script =
  let now = ref 0. in
  let looks = ref 0 in
  let flees = ref 0 in
  let next = next_of script in
  let look () =
    incr looks;
    now := !now +. float_of_int rule.look_every_ms;
    let facts, unchanged_for_ms = next () in
    let since_ms = Option.map (fun ms -> !now -. ms) unchanged_for_ms in
    { Settle.facts; at_ms = !now; since_ms }
  in
  let flee_battle () =
    incr flees;
    true
  in
  let io : Settle.io =
    { look; press = (fun _ ~wait_ms:_ -> None); flee_battle; log = ignore }
  in
  let ending = Settle.run rule ~label:"Step" io in
  Printf.sprintf "%s after %d looks, %d flees" (ending_text ending) !looks
    !flees

(* A door's settle looked at every 400 ms, as FRLG watches. *)
let watched_door ~watch_battles =
  { door with look_every_ms = 400; watch_battles }

let watch_case name rule script expectation =
  { Table_test.name; input = (fun () -> run_watching rule script); expectation }

let () =
  Table_test.run "Settle.run, watching"
    [
      (* Quiet from 50 ms into the first look: 1 s of it by the third look's
         end (1200 ms), not the fourth (1600 ms, 1 s from the first look's
         end). *)
      watch_case "a quiet that began early in a look counts from then"
        (watched_door ~watch_battles:false)
        [
          (quiet, Some 350.);
          (quiet, Some 750.);
          (quiet, Some 1150.);
          (quiet, Some 1550.);
        ]
        "quiet after 3 looks, 0 flees";
      watch_case "with no since, the quiet counts from the look"
        (watched_door ~watch_battles:false)
        [ (quiet, None) ]
        "quiet after 4 looks, 0 flees";
      (* 1 s of quiet after the battle: from the third look (1200 ms) to the
         sixth (2400 ms). *)
      watch_case "a battle on screen is watched, not fled"
        (watched_door ~watch_battles:true)
        [ (quiet, None); (battle, None); (quiet, None) ]
        "quiet after 6 looks, 0 flees";
    ]
