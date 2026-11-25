(* Party_summary and Party_species on a scripted party (Scripted_party): every
   member read in one pass over the summaries, the party opened once and
   closed once, on mGBA's timing and on console B's capture latency. *)

open Frlg_actions
module S = Frlg_overworld_fixtures.Scripted_screen
module Party = Frlg_overworld_fixtures.Scripted_party

let case name input expectation = { Table_test.name; input; expectation }

let six ?(late = 0) () =
  Party.
    [
      member "BLASTOISE" 59 ~moves:[ "BITE"; "STRENGTH"; "SURF"; "BLIZZARD" ];
      member "EEVEE" 25 ~moves:[ "GROWL"; "QUICK ATTACK" ];
      member "PIDGEY" 24 ~moves:[ "GUST"; "FLY" ] ~draw_ms:late;
      member "ODDISH" 12 ~moves:[ "ABSORB"; "CUT" ];
      member "LAPRAS" 25 ~moves:[ "MIST"; "BODY SLAM" ];
      member "MAGIKARP" 5 ~moves:[ "SPLASH" ];
    ]

let screen ?latencies members =
  S.create ~react:(Party.react members) ?capture_latencies_ms:latencies ()

let ends_on screen = S.screen_name (S.screen_at screen screen.S.clock_ms)

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Checkpoints.Failure.cause_to_string cause

(* What was read, how many times the menu opened, where it ended. *)
let summary_of ?latencies members () =
  let screen = screen ?latencies members in
  let read = ref [] in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> read := Party_summary.read_all ~log:ignore ()))
  in
  Printf.sprintf "%s: %s; START x%d; ends on %s" (outcome result)
    (String.concat "; "
       (List.map Checkpoints.Room_policy.member_to_string !read))
    (Party.count screen Wire.Start)
    (ends_on screen)

let presses members () =
  let screen = screen members in
  ignore
    (S.run screen (fun () ->
         Menu_input.run (fun () ->
             ignore (Party_summary.read_all ~log:ignore ()))));
  Printf.sprintf "%s; %.1f s" (S.presses_text screen)
    (float_of_int screen.S.clock_ms /. 1000.)

let species_of ?latencies members () =
  let screen = screen ?latencies members in
  let read = ref [] in
  let result =
    S.run screen (fun () ->
        Menu_input.run (fun () -> read := Party_species.read_all ~log:ignore))
  in
  Printf.sprintf "%s: %s; START x%d; ends on %s" (outcome result)
    (String.concat ", " (List.map (Option.value ~default:"?") !read))
    (Party.count screen Wire.Start)
    (ends_on screen)

let read_six =
  "ok: blastoise Lv 59 (bite, strength, surf, blizzard); eevee Lv 25 (growl, \
   quick-attack); pidgey Lv 24 (gust, fly); oddish Lv 12 (absorb, cut); lapras \
   Lv 25 (mist, body-slam); magikarp Lv 5 (splash); START x1; ends on \
   overworld"

let console_b = [ 160; 335 ]

let () =
  Table_test.run "party_summary"
    [
      case "six members: the party opened once, closed once"
        (summary_of (six ()))
        read_six;
      case
        "six members' presses and time: DOWN to the next on the info page \
         (77.6 s one member at a time)"
        (presses (six ()))
        "Start, A x3, right x2, left x2, down, right x2, left x2, down, right \
         x2, left x2, down, right x2, left x2, down, right x2, left x2, down, \
         right x2, left x2, B x6; 24.7 s";
      case "a member whose info page draws 600 ms after the switch"
        (summary_of (six ~late:600 ()))
        read_six;
      case "console B's capture latency (160 and 335 ms)"
        (summary_of ~latencies:console_b (six ()))
        read_six;
      case "species only: one pass on the info pages"
        (species_of ~latencies:console_b (six ~late:600 ()))
        "ok: blastoise, eevee, pidgey, oddish, lapras, magikarp; START x1; \
         ends on overworld";
    ]
