type kind = Talk | After_warp | Menu_closed

type rule = {
  judge : Talk_over.rule;
  look_every_ms : int;
  cap_ms : int;
  watch_battles : bool;
}

(* A line's text takes about a second to run out. *)
let talk_look_every_ms = 1200
let cap_ms = 120_000

let talk_rule =
  {
    judge = Talk_over.default_rule;
    look_every_ms = talk_look_every_ms;
    cap_ms;
    watch_battles = false;
  }

(* A menu closed to the overworld: no text or scene comes after it, so a short
   quiet ends it, looking often. A game whose fade-in can hold still (FireRed's
   dim spell) reports no free control until it is over. *)
let menu_quiet_ms = 500
let menu_calm_ms = 2500
let menu_look_every_ms = 300

(* Out of the deepest menu (a summary) is three screens and their fades. *)
let menu_cap_ms = 15_000

let menu_judge =
  {
    Talk_over.default_rule with
    calm_ms = menu_calm_ms;
    quiet_ms = menu_quiet_ms;
  }

let rule = function
  | Talk -> talk_rule
  | After_warp ->
      { talk_rule with judge = { talk_rule.judge with warp = true } }
  | Menu_closed ->
      {
        talk_rule with
        judge = menu_judge;
        look_every_ms = menu_look_every_ms;
        cap_ms = menu_cap_ms;
      }

type reading = { facts : Facts.t; at_ms : float; since_ms : float option }

type game_steps = {
  read : unit -> reading;
  press : Talk_over.press -> wait_ms:int -> reading option;
  flee_battle : unit -> bool;
  log : string -> unit;
}

type ending = Quiet of string | Battle of string | Timed_out of string

let ms_per_s = 1000

let timed_out judge rule label =
  let seconds = rule.cap_ms / ms_per_s in
  if not (Talk_over.warped judge) then
    Printf.sprintf
      "%s: no fade or banner within %d s, so we are not where the step goes \
       (map mismatch)."
      label seconds
  else if not rule.judge.end_on_quiet then
    Printf.sprintf "%s: no battle within %d s of the talk." label seconds
  else
    Printf.sprintf "%s: not back on a quiet overworld within %d s." label
      seconds

(* The screen showed the look's facts from [since_ms] on: the judge sees them
   then too, so their quiet counts from there. *)
let observe judge look =
  let judge =
    match look.since_ms with
    | Some since when since < look.at_ms ->
        fst (Talk_over.observe judge look.facts ~at_ms:since)
    | Some _ | None -> judge
  in
  Talk_over.observe judge look.facts ~at_ms:look.at_ms

let log io fmt = Printf.ksprintf (fun s -> io.log ("[Settle] " ^ s)) fmt

(* After a move: the settle ends, or the next look, with the frame the
   press's wait saw a warp on, if it did. *)
type next = End of ending | Look_again of reading option

(* Acts on the judge's move. *)
let answer rule ~label io judge = function
  | Talk_over.Done ->
      log io "%s: over; %s." label (Talk_over.describe judge);
      End (Quiet (Talk_over.describe judge))
  | Talk_over.Battle when rule.watch_battles -> Look_again None
  | Talk_over.Battle ->
      if io.flee_battle () then (
        log io "%s: fled a wild battle." label;
        Look_again None)
      else (
        log io "%s: a battle started." label;
        End (Battle (Talk_over.describe judge)))
  | Talk_over.Press press ->
      Look_again (io.press press ~wait_ms:rule.look_every_ms)

(* A frame the press's wait saw a warp on, while the warp is still to come:
   the judge sees it before the next look, at its own time. Once warped the
   looks alone time the quiet. *)
let observe_seen judge = function
  | Some seen when not (Talk_over.warped judge) ->
      fst (Talk_over.observe judge seen.facts ~at_ms:seen.at_ms)
  | Some _ | None -> judge

let run ?seen rule ~label io =
  let first = io.read () in
  let deadline = first.at_ms +. float_of_int rule.cap_ms in
  let rec loop judge look =
    if look.at_ms >= deadline then (
      let failure = timed_out judge rule label in
      log io "%s" failure;
      Timed_out failure)
    else
      let judge, move = observe judge look in
      match answer rule ~label io judge move with
      | End ending -> ending
      | Look_again seen -> loop (observe_seen judge seen) (io.read ())
  in
  loop (observe_seen (Talk_over.create rule.judge) seen) first
