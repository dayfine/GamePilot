(* Round_trials decides, after each round of a repeating checkpoint (mg-04b's
   grind round), whether to run another, go on (the goal holds) or stop. *)

open Story
open Round_trials

let decide_text ?(capped = false) ?(max_rounds = 20) rounds =
  decision_to_string (decide ~max_rounds ~capped rounds)

let pass = Round_passed { goal_met = false }
let goal = Round_passed { goal_met = true }

let failed =
  Round_failed
    "the same step failed twice (#2 to_spot): no path to VictoryRoad_2F (45, \
     10)"

let case ?capped ?max_rounds name rounds expectation : Table_test.case =
  {
    name;
    input = (fun () -> decide_text ?capped ?max_rounds rounds);
    expectation;
  }

let cases =
  [
    case "no round yet: run the first" [] "round 1";
    case "a round passed, the goal not met: the next" [ pass; pass ] "round 3";
    case "the goal holds after round 3: on to the next checkpoint"
      [ pass; pass; goal ] "goal met after 3 rounds";
    case "the goal holds after the first round (a resumed run)" [ goal ]
      "goal met after 1 round";
    case "max rounds passed, the goal not met: stopped" ~max_rounds:2
      [ pass; pass ] "stopped: goal not met after 2 rounds";
    case "capped for testing: max rounds is a pass" ~capped:true ~max_rounds:2
      [ pass; pass ] "capped after 2 rounds";
    case "a round out of retries stops the rounds" [ pass; failed ]
      "stopped: round 2 failed: the same step failed twice (#2 to_spot): no \
       path to VictoryRoad_2F (45, 10)";
    case "the goal met in the last allowed round still passes" ~max_rounds:2
      [ pass; goal ] "goal met after 2 rounds";
  ]

let () = Table_test.run "round_trials" cases
