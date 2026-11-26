module S = Plza_readers.Mystery_gift_screen
module R = Plza_readers.Main_menu_row
module T = Switch_home.Timed_press

type screen = Main_menu | Card | Question of S.answer | Message | Other

let screen m =
  if R.highlighted m <> None then Main_menu
  else if S.card m then Card
  else
    match S.question m with
    | Some answer -> Question answer
    | None -> if S.message m then Message else Other

let screen_text = function
  | Main_menu -> "the main menu"
  | Card -> "a gift's card"
  | Question Yes -> "a question, Yes highlighted"
  | Question No -> "a question, No highlighted"
  | Message -> "a message"
  | Other -> "another screen"

let hold_ms = 1000.
let read_ms = 2500

(* The screen held 1 s within 2.5 s, and the last frame read. *)
let read () =
  let last = ref None in
  let watch m =
    last := Some m;
    Some (screen m)
  in
  let held =
    Switch_home.Held_screen.wait_for ~timeout_ms:read_ms
      (Switch_home.Held_screen.held hold_ms watch)
  in
  (held, !last)

let a : T.t = { button = A; hold_ms = 100; cooldown_ms = 2500 }
let b : T.t = { button = B; hold_ms = 100; cooldown_ms = 1500 }
let up : T.t = { button = Up; hold_ms = 80; cooldown_ms = 300 }
let most_presses = 12

(* The press for a screen read; B for one that did not hold. *)
let press_for = function
  | Some Main_menu -> None
  | Some (Question Yes | Message) -> Some ("A", a)
  | Some (Question No) -> Some ("Up", up)
  | Some (Card | Other) | None -> Some ("B", b)

let reading last = Option.fold ~none:"no frame" ~some:S.describe last

let step_line held button =
  Printf.sprintf "Leaving the gifts: %s, %s."
    (Option.fold ~none:"no steady screen" ~some:screen_text held)
    button

let out_of_presses last =
  Error
    (Printf.sprintf "no main menu after %d presses (%s)" most_presses
       (reading last))

let to_main_menu ~log =
  let rec go n =
    let held, last = read () in
    match press_for held with
    | None -> Ok ()
    | Some _ when n >= most_presses -> out_of_presses last
    | Some (button, p) ->
        log (step_line held button);
        T.press p;
        go (n + 1)
  in
  go 0
