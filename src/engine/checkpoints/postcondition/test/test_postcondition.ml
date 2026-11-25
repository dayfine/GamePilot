(* Postcondition: verdicts, the count and money checks against the start, and the
   log over results, apart from any game's promises; Count and Money as text. *)

open Engine_postcondition

let case name input expectation : Table_test.case =
  {
    name;
    input = (fun () -> Postcondition.result_to_string (input ()));
    expectation;
  }

let judge_cases =
  [
    case "judged true: passed, with what was read"
      (fun () -> Postcondition.judge "flag x" ~expected:"set" ~read:"set" true)
      "flag x: passed: set";
    case "judged false: failed, with what was expected and read"
      (fun () ->
        Postcondition.judge "flag x" ~expected:"set" ~read:"clear" false)
      "flag x: failed: expected set, read clear";
    case "not read: not checked, never passed"
      (fun () -> Postcondition.not_read "flag x")
      "flag x: not checked: the game can't read it";
    case "not checked, with why"
      (fun () -> Postcondition.not_checked "party" ~why:"read ?, abra")
      "party: not checked: read ?, abra";
  ]

let count_cases =
  [
    case "exactly, as read"
      (fun () -> Postcondition.count "coins" (Exactly 20) ~start:None ~read:20)
      "coins: passed: 20";
    case "exactly, off"
      (fun () -> Postcondition.count "coins" (Exactly 20) ~start:None ~read:200)
      "coins: failed: expected 20, read 200";
    case "at least, at the floor"
      (fun () ->
        Postcondition.count "item rope" (At_least 2) ~start:None ~read:2)
      "item rope: passed: 2";
    case "at least, below"
      (fun () ->
        Postcondition.count "item rope" (At_least 2) ~start:None ~read:1)
      "item rope: failed: expected at least 2, read 1";
    case "gained, as promised"
      (fun () ->
        Postcondition.count "coins" (Gained 20) ~start:(Some 50) ~read:70)
      "coins: passed: gained 20 (50 to 70)";
    case "gained, by another amount"
      (fun () -> Postcondition.count "coins" (Gained 1) ~start:(Some 2) ~read:5)
      "coins: failed: expected gained 1, read gained 3 (2 to 5)";
    case "used, as promised"
      (fun () ->
        Postcondition.count "item rope" (Gained (-1)) ~start:(Some 4) ~read:3)
      "item rope: passed: used 1 (4 to 3)";
    case "gained, the start not read"
      (fun () -> Postcondition.count "coins" (Gained 20) ~start:None ~read:20)
      "coins: not checked: the count at the start was not read";
  ]

let money_cases =
  [
    case "a single amount, as read"
      (fun () ->
        Postcondition.money
          (Range { min = 25014; max = 25014 })
          ~start:None ~read:25014)
      "money: passed: $25014";
    case "a range, at its top"
      (fun () ->
        Postcondition.money
          (Range { min = 100; max = 200 })
          ~start:None ~read:200)
      "money: passed: $200";
    case "a range, below it"
      (fun () ->
        Postcondition.money
          (Range { min = 100; max = 200 })
          ~start:None ~read:99)
      "money: failed: expected $100 to $200, read $99";
    case "spent, as promised"
      (fun () ->
        Postcondition.money (Spent 4100) ~start:(Some 29202) ~read:25102)
      "money: passed: spent $4100 ($29202 to $25102)";
    case "spent more than promised"
      (fun () ->
        Postcondition.money (Spent 4100) ~start:(Some 29202) ~read:25014)
      "money: failed: expected spent $4100, read spent $4188 ($29202 to $25014)";
    case "spent, the start not read"
      (fun () -> Postcondition.money (Spent 4100) ~start:None ~read:25102)
      "money: not checked: the money at the start was not read";
  ]

let passed = Postcondition.judge "coins" ~expected:"20" ~read:"20" true
let failed = Postcondition.judge "money" ~expected:"$1" ~read:"$2" false
let unread = Postcondition.not_read "flag x"

let text_case name input expectation : Table_test.case =
  { name; input = (fun () -> String.concat "\n" (input ())); expectation }

let list_cases =
  [
    text_case "unmet: the failed and the not checked, in order"
      (fun () ->
        List.map Postcondition.result_to_string
          (Postcondition.unmet [ passed; failed; unread ]))
      "money: failed: expected $1, read $2\n\
       flag x: not checked: the game can't read it";
    text_case "the log: one line per result, tagged, then the summary"
      (fun () -> Postcondition.log_lines ~tag:"Start" "cf-01" [ passed ])
      "[Start] cf-01 coins: passed: 20\n\
       [Start] cf-01: 1 passed, 0 failed, 0 not checked: passed";
  ]

(* The log's last line: its summary. *)
let summary results =
  match List.rev (Postcondition.log_lines ~tag:"P" "c" results) with
  | last :: _ -> last
  | [] -> "no lines"

let summary_case name results expectation : Table_test.case =
  { name; input = (fun () -> summary results); expectation }

let summary_cases =
  [
    summary_case "the summary: passed when every one passed" [ passed ]
      "[P] c: 1 passed, 0 failed, 0 not checked: passed";
    summary_case "the summary: failed when one failed"
      [ passed; failed; unread ]
      "[P] c: 1 passed, 1 failed, 1 not checked: failed";
    summary_case "the summary: incomplete when none failed and one not checked"
      [ passed; unread ] "[P] c: 1 passed, 0 failed, 1 not checked: incomplete";
    summary_case "the summary: nothing to check for none" []
      "[P] c: 0 passed, 0 failed, 0 not checked: nothing to check";
  ]

let text_cases =
  [
    text_case "a count of exactly 2" (fun () -> [ Count.text (Exactly 2) ]) "x2";
    text_case "a count gained" (fun () -> [ Count.text (Gained 2) ]) "gained 2";
    text_case "a count used" (fun () -> [ Count.text (Gained (-1)) ]) "used 1";
    text_case "a floor" (fun () -> [ Count.text (At_least 100) ]) "at least 100";
    text_case "a money range"
      (fun () -> [ Money.text (Range { min = 100; max = 200 }) ])
      "money 100 to 200";
    text_case "money spent"
      (fun () -> [ Money.text (Spent 4100) ])
      "money spent 4100";
  ]

let () =
  Table_test.run "promise"
    (judge_cases @ count_cases @ money_cases @ list_cases @ summary_cases
   @ text_cases)
