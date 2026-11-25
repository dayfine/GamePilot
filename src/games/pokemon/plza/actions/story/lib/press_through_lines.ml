module S = Story_steps
module L = Story_look

type passed = { text : bool; card : bool; timed_out : bool }

let poll_ms = 250
let a_hold_ms = 160
let a_release_ms = 240

type state = {
  passed : passed;
  start : float option;
  quiet_since : float option;
  looks : int;
}

let timed_out s = { s.passed with timed_out = true }

let pressed s ~card ~text =
  {
    s with
    passed =
      {
        s.passed with
        card = s.passed.card || card;
        text = s.passed.text || text;
      };
    quiet_since = None;
  }

let rec go steps ~quiet_ms ~limit_ms ~max_looks s =
  let look = S.(steps.read_screen) () in
  if s.looks >= max_looks || look.home_menu then timed_out s
  else
    let start = Option.value s.start ~default:look.at_ms in
    step steps ~quiet_ms ~limit_ms ~max_looks
      { s with start = Some start; looks = s.looks + 1 }
      look ~start

(* After a read: the limit, else the next read ([wait] 250 ms first). *)
and next steps ~quiet_ms ~limit_ms ~max_looks (look : L.t) ~start ~wait s =
  if look.at_ms -. start >= float_of_int limit_ms then timed_out s
  else (
    if wait then S.wait steps poll_ms;
    go steps ~quiet_ms ~limit_ms ~max_looks s)

and step steps ~quiet_ms ~limit_ms ~max_looks s (look : L.t) ~start =
  let card = look.tutorial_card and text = L.text_shows look in
  let next = next steps ~quiet_ms ~limit_ms ~max_looks look ~start in
  let since = Option.value s.quiet_since ~default:look.at_ms in
  if card || text then (
    S.press steps Wire.A ~hold_ms:a_hold_ms ~release_ms:a_release_ms;
    next ~wait:false (pressed s ~card ~text))
  else if look.at_ms -. since >= float_of_int quiet_ms then s.passed
  else next ~wait:true { s with quiet_since = Some since }

let run steps ~quiet_ms ~limit_ms =
  go steps ~quiet_ms ~limit_ms
    ~max_looks:((limit_ms / poll_ms) + 1)
    {
      passed = { text = false; card = false; timed_out = false };
      start = None;
      quiet_since = None;
      looks = 0;
    }
