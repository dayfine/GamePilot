type screen = Yes_no | Paged_text | Text | Start_menu | Nothing

type action =
  | Wait
  | Answer_yes
  | Next_page
  | Check_overworld
  | Fail_cancelled
  | Fail_error

type t = { paged_since_yes : bool; nothing_seen : int }

let start = { paged_since_yes = false; nothing_seen = 0 }

(* Twice in a row: not the frame between two boxes. *)
let nothing_needed = 2

let next t screen =
  let t = if screen = Nothing then t else { t with nothing_seen = 0 } in
  match screen with
  | Yes_no -> ({ t with paged_since_yes = false }, Answer_yes)
  | Paged_text -> ({ t with paged_since_yes = true }, Next_page)
  | Text -> (t, Wait)
  | Start_menu -> (t, Fail_cancelled)
  | Nothing ->
      let t = { t with nothing_seen = t.nothing_seen + 1 } in
      if t.nothing_seen < nothing_needed then (t, Wait)
      else (t, if t.paged_since_yes then Fail_error else Check_overworld)

let screen_name = function
  | Yes_no -> "yes/no"
  | Paged_text -> "paged text"
  | Text -> "text"
  | Start_menu -> "start menu"
  | Nothing -> "nothing"

let action_name = function
  | Wait -> "wait"
  | Answer_yes -> "answer yes"
  | Next_page -> "next page"
  | Check_overworld -> "check overworld"
  | Fail_cancelled -> "fail: cancelled"
  | Fail_error -> "fail: save error"
