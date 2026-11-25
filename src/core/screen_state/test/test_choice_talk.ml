(* Choice_talk's moves for the looks that decide a talk's end. *)

open Screen_state

let name = function
  | Choice_talk.Pick -> "pick"
  | Next_page -> "next page"
  | Answered -> "answered"
  | Wait -> "wait"

let none = { Choice_talk.choice = false; page = false; past_choice = false }
let party = { none with past_choice = true }
let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "choice_talk"
    [
      case "a choice box gets a pick, even over its text"
        (fun () ->
          name
            (Choice_talk.move ~pressed:true
               { none with choice = true; page = true }))
        "pick";
      case
        "the screen after the choice, once a press of ours went in: our A took \
         the default (mg-02 testing on console B, 2026-11-24)"
        (fun () -> name (Choice_talk.move ~pressed:true party))
        "answered";
      case "the same screen before any press of ours is not an answer"
        (fun () -> name (Choice_talk.move ~pressed:false party))
        "wait";
    ]
