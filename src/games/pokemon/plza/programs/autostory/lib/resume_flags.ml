module S = Plza_story.Story_steps
module L = Plza_story.Story_look

let reads = 5
let poll_ms = 250

let talk_or_battle (l : L.t) =
  L.text_shows l || l.choice_box || l.tutorial_card || l.battle
  || L.fade_shows l

let flags =
  [
    ("talk_or_battle_shows", talk_or_battle);
    ("battle_shows", fun (l : L.t) -> l.battle);
  ]

(* Any of [reads] reads, [poll_ms] apart, shows it. *)
let rec seen steps shows n =
  let look = S.(steps.read_screen) () in
  if shows look then (
    S.(steps.log) (Printf.sprintf "[PLZA] resume: %s." (L.describe look));
    true)
  else if n <= 1 then false
  else (
    S.wait steps poll_ms;
    seen steps shows (n - 1))

let holds steps flag =
  match List.assoc_opt flag flags with
  | Some shows -> seen steps shows reads
  | None ->
      S.(steps.log)
        (Printf.sprintf "[PLZA] unknown skip_if flag %S: does not hold." flag);
      false
