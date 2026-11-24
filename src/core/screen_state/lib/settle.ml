type kind = Talk | After_warp | Door | Menu_closed

type rule = {
  judge : Talk_over.rule;
  look_every_ms : int;
  cap_ms : int;
  watch_battles : bool;
}

(* A line's text takes about a second to run out. *)
let talk_look_every_ms = 1200
let cap_ms = 120_000

(* A door's settle: the player still this long after the fade is back up ends
   it; a walk any earlier could still go nowhere in the fade-in (BDSP lab-B
   2026-11-10, 00.04b's nurse). *)
let door_quiet_ms = 1000

(* A door's settle: the overworld back up this long ends it, still or not
   (someone walking past the player the whole time). *)
let door_calm_ms = 2500

(* A door has no text: look often to catch its short still spell. *)
let door_look_every_ms = 200

let talk_rule =
  {
    judge = Talk_over.default_rule;
    look_every_ms = talk_look_every_ms;
    cap_ms;
    watch_battles = false;
  }

let door_judge =
  {
    Talk_over.default_rule with
    calm_ms = door_calm_ms;
    quiet_ms = door_quiet_ms;
    still = Player;
  }

(* A menu closed to the overworld: no text or scene comes after it, so a short
   quiet ends it (a fade-in is never still), looking often. *)
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
  | Door ->
      { talk_rule with judge = door_judge; look_every_ms = door_look_every_ms }
  | Menu_closed ->
      {
        talk_rule with
        judge = menu_judge;
        look_every_ms = menu_look_every_ms;
        cap_ms = menu_cap_ms;
      }

type look = { facts : Facts.t; at_ms : float; since_ms : float option }

type io = {
  look : unit -> look;
  press : Talk_over.press -> wait_ms:int -> unit;
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

(* Acts on the judge's move: the ending, or [None] to look again. *)
let answer rule ~label io judge = function
  | Talk_over.Done ->
      log io "%s: over; %s." label (Talk_over.describe judge);
      Some (Quiet (Talk_over.describe judge))
  | Talk_over.Battle when rule.watch_battles -> None
  | Talk_over.Battle ->
      if io.flee_battle () then (
        log io "%s: fled a wild battle." label;
        None)
      else (
        log io "%s: a battle started." label;
        Some (Battle (Talk_over.describe judge)))
  | Talk_over.Press press ->
      io.press press ~wait_ms:rule.look_every_ms;
      None

let run rule ~label io =
  let first = io.look () in
  let deadline = first.at_ms +. float_of_int rule.cap_ms in
  let rec loop judge look =
    if look.at_ms >= deadline then (
      let failure = timed_out judge rule label in
      log io "%s" failure;
      Timed_out failure)
    else
      let judge, move = observe judge look in
      match answer rule ~label io judge move with
      | Some ending -> ending
      | None -> loop judge (io.look ())
  in
  loop (Talk_over.create rule.judge) first
