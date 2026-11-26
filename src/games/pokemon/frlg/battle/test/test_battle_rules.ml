(* The battle steps' decisions on reader facts, with no screen: which screen
   a look's facts make, what next_event does at each look (Event_rule), and
   where the cursors go (Battle_cursor). *)

open Frlg_battle

let f = Battle_look.nothing
let text = { f with text_box = true; player_box = true; foe_box = true }
let arrow = { text with arrow = true }
let evolving = { f with text_box = true; evolution = true }

let classify_cases : Table_test.case list =
  let case name facts expectation : Table_test.case =
    {
      name;
      input = (fun () -> Battle_look.(screen_name (classify facts)));
      expectation;
    }
  in
  [
    case "nothing: no battle" f "no battle";
    case "an HP box alone: the battle runs on" { f with foe_box = true }
      "battle text";
    case "the action menu over the text box"
      { text with action_menu = true }
      "action menu";
    case "the move menu where the action menu reads too"
      { text with action_menu = true; move_menu = true }
      "move menu";
    case "the level-up box over the text box"
      { text with level_up = true }
      "level up";
    case "a YES/NO over everything"
      { text with yes_no = true; party_list = true }
      "yes/no";
    case "the party list over the bag"
      { f with party_list = true; bag = true }
      "party list";
    case "the arrow under the level-up box: level up"
      { text with level_up = true; arrow = true }
      "level up";
    case "the arrow on battle text" { text with arrow = true } "text arrow";
    case "text with no HP box and no arrow: what an evolution shows"
      { f with text_box = true; evolution = true }
      "evolution";
  ]

let step_name : Event_rule.step -> string = function
  | Report e -> Battle.event_name e
  | Press b -> "press " ^ Wire.string_of_button b
  | Look -> "look"

(* Looks at the given times from a start at 0; the steps they get. *)
let steps looks () =
  let _, names =
    List.fold_left
      (fun (state, names) (facts, at_ms) ->
        let state, step = Event_rule.next state facts ~at_ms in
        (state, step_name step :: names))
      (Event_rule.start ~at_ms:0., [])
      looks
  in
  String.concat ", " (List.rev names)

let rule_cases : Table_test.case list =
  let case name looks expectation : Table_test.case =
    { name; input = steps looks; expectation }
  in
  [
    case "the action menu is reported at once"
      [ ({ text with action_menu = true }, 100.) ]
      "action menu";
    case "the party list the game opened: a switch-in"
      [ ({ f with party_list = true }, 100.) ]
      "switch-in";
    case "a YES/NO with the player's box beside it: a move to learn"
      [ ({ text with yes_no = true; move_learn = true }, 100.) ]
      "move learn";
    case "a YES/NO with the player's box gone: use next"
      [ ({ f with yes_no = true; foe_box = true }, 100.) ]
      "use next";
    case "the arrow gets B at once, then not again within 0.5 s"
      [ (arrow, 500.); (arrow, 700.); (arrow, 1000.) ]
      "press B, look, press B";
    case "text with no arrow is left to run on until 6 s without a press"
      [ (text, 1500.); (text, 5900.); (text, 6000.) ]
      "look, look, press B";
    case "after a level-up, an evolution never gets a press"
      [
        ({ text with level_up = true }, 1500.);
        (evolving, 2000.);
        (evolving, 10000.);
        (evolving, 30000.);
      ]
      "press A, look, look, look";
    case
      "with no level-up, text with no HP box (Lea & Jed's defeat line) gets B \
       after 6 s"
      [ (evolving, 1000.); (evolving, 5900.); (evolving, 6000.) ]
      "look, look, press B";
    case "the level-up box gets A"
      [ ({ text with level_up = true }, 1500.) ]
      "press A";
    case "a stray move menu gets B"
      [ ({ text with move_menu = true }, 2000.) ]
      "press B";
    case "no battle before one showed: the opening is awaited"
      [ (f, 1000.); (f, 5000.); (f, 20000.) ]
      "look, look, look";
    case "no battle for 3 s after one: over"
      [ (text, 100.); (f, 1000.); (f, 3500.); (f, 4000.) ]
      "look, look, look, battle over";
    case "a battle screen starts the 3 s over"
      [ (text, 100.); (f, 1000.); (text, 3000.); (f, 3500.); (f, 6000.) ]
      "look, look, look, look, look";
  ]

let buttons bs = String.concat " " (List.map Wire.string_of_button bs)

let cursor_cases : Table_test.case list =
  let case name presses expectation : Table_test.case =
    { name; input = (fun () -> buttons presses); expectation }
  in
  [
    case "move 0, top left" (Battle_cursor.move ~slot:0) "Left Up";
    case "move 1, top right" (Battle_cursor.move ~slot:1) "Left Up Right";
    case "move 2, bottom left" (Battle_cursor.move ~slot:2) "Left Up Down";
    case "move 3, bottom right"
      (Battle_cursor.move ~slot:3)
      "Left Up Right Down";
    case "the ally: one RIGHT past the user" (Battle_cursor.target Ally) "Right";
    case "the foe on the right: one LEFT"
      (Battle_cursor.target Foe_right)
      "Left";
    case "the foe on the left: where the cursor starts"
      (Battle_cursor.target Foe_left)
      "";
  ]

let () =
  Table_test.run "battle look" classify_cases;
  Table_test.run "event rule" rule_cases;
  Table_test.run "battle cursor" cursor_cases
