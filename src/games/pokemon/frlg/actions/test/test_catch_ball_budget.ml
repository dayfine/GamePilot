(* Gen 3 capture ball budget calculations across catch-rate tiers, ball
   multipliers, catch modes, and edge cases. *)

open Frlg_actions
module B = Catch_ball_budget

let case name input expectation = { Table_test.name; input; expectation }
let fmt_opt = function None -> "none" | Some n -> string_of_int n
let budget species ball mode () = fmt_opt (B.required ~species ~ball ~mode)

let tier_cases =
  [
    (* CR 255: Oddish *)
    case "CR 255 (oddish), luxury-ball (1x), throw_only"
      (budget "oddish" "luxury-ball" Throw_only)
      "12";
    case "CR 255 (oddish), poke-ball (1x), throw_only"
      (budget "oddish" "poke-ball" Throw_only)
      "12";
    case "CR 255 (oddish), great-ball (1.5x), throw_only"
      (budget "oddish" "great-ball" Throw_only)
      "7";
    case "CR 255 (oddish), ultra-ball (2x), throw_only"
      (budget "oddish" "ultra-ball" Throw_only)
      "5";
    case "CR 255 (oddish), master-ball, throw_only"
      (budget "oddish" "master-ball" Throw_only)
      "1";
    case "CR 255 (oddish), luxury-ball (1x), weakened_asleep (clamped to min 5)"
      (budget "oddish" "luxury-ball" Weakened_asleep)
      "5";
    case "CR 255 (oddish), ultra-ball (2x), weakened_asleep (clamped to min 5)"
      (budget "oddish" "ultra-ball" Weakened_asleep)
      "5";
    (* CR 190: Growlithe / Psyduck *)
    case "CR 190 (growlithe), luxury-ball (1x), throw_only"
      (budget "growlithe" "luxury-ball" Throw_only)
      "17";
    case "CR 190 (psyduck), ultra-ball (2x), throw_only"
      (budget "psyduck" "ultra-ball" Throw_only)
      "7";
    case "CR 190 (growlithe), master-ball, throw_only"
      (budget "growlithe" "master-ball" Throw_only)
      "1";
    case "CR 190 (psyduck), luxury-ball (1x), weakened_asleep"
      (budget "psyduck" "luxury-ball" Weakened_asleep)
      "5";
    case "CR 190 (growlithe), ultra-ball (2x), weakened_asleep"
      (budget "growlithe" "ultra-ball" Weakened_asleep)
      "5";
    (* CR 45: Electabuzz / Scyther *)
    case "CR 45 (electabuzz), luxury-ball (1x), throw_only"
      (budget "electabuzz" "luxury-ball" Throw_only)
      "76";
    case "CR 45 (scyther), ultra-ball (2x), throw_only"
      (budget "scyther" "ultra-ball" Throw_only)
      "37";
    case "CR 45 (electabuzz), master-ball, throw_only"
      (budget "electabuzz" "master-ball" Throw_only)
      "1";
    case "CR 45 (electabuzz), luxury-ball (1x), weakened_asleep"
      (budget "electabuzz" "luxury-ball" Weakened_asleep)
      "11";
    case "CR 45 (scyther), great-ball (1.5x), weakened_asleep"
      (budget "scyther" "great-ball" Weakened_asleep)
      "7";
    case "CR 45 (scyther), ultra-ball (2x), weakened_asleep (clamped to min 5)"
      (budget "scyther" "ultra-ball" Weakened_asleep)
      "5";
    (* CR 3: Zapdos *)
    case "CR 3 (zapdos), luxury-ball (1x), throw_only (clamped to max 99)"
      (budget "zapdos" "luxury-ball" Throw_only)
      "99";
    case "CR 3 (zapdos), ultra-ball (2x), throw_only (clamped to max 99)"
      (budget "zapdos" "ultra-ball" Throw_only)
      "99";
    case "CR 3 (zapdos), luxury-ball (1x), weakened_asleep (clamped to max 99)"
      (budget "zapdos" "luxury-ball" Weakened_asleep)
      "99";
    case "CR 3 (zapdos), ultra-ball (2x), weakened_asleep"
      (budget "zapdos" "ultra-ball" Weakened_asleep)
      "96";
    case "CR 3 (zapdos), master-ball, throw_only"
      (budget "zapdos" "master-ball" Throw_only)
      "1";
  ]

let edge_cases =
  [
    case "unknown species with standard ball returns None"
      (budget "missingno" "ultra-ball" Throw_only)
      "none";
    case "unknown species with master-ball still returns 1"
      (budget "missingno" "master-ball" Throw_only)
      "1";
    case "unknown ball returns None"
      (budget "oddish" "safari-ball" Throw_only)
      "none";
    case "unown form slug resolves to CR 225"
      (fun () -> fmt_opt (B.catch_rate "unown-a"))
      "225";
    case "catch_mode_of_string maps phase1/phase2 to Weakened_asleep"
      (fun () ->
        let show = function
          | B.Throw_only -> "throw"
          | B.Weakened_asleep -> "sleep"
        in
        String.concat ","
          (List.map
             (fun s -> show (B.catch_mode_of_string s))
             [ None; Some "throw_only"; Some "phase1"; Some "phase2" ]))
      "throw,throw,sleep,sleep";
  ]

let () = Table_test.run "catch ball budget" (tier_cases @ edge_cases)
