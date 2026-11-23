type still_source = Screen | Player

type rule = {
  warp : bool;
  end_on_quiet : bool;
  calm_ms : int;
  quiet_ms : int;
  still : still_source;
}

let quiet_ms = 5000
let calm_ms = 15000

let default_rule =
  { warp = false; end_on_quiet = true; calm_ms; quiet_ms; still = Screen }

type press = Next | B
type move = Press of press | Battle | Done

type t = {
  rule : rule;
  first_fade : Fade.t;  (** the first fade seen *)
  fade_showing : Fade.t;  (** the one the last look showed *)
  banner : bool;
  quiet_since : float option;
  calm_since : float option;
}

let create rule =
  {
    rule;
    first_fade = No_fade;
    fade_showing = No_fade;
    banner = false;
    quiet_since = None;
    calm_since = None;
  }

let warped t = (not t.rule.warp) || t.first_fade <> No_fade || t.banner

(* Since when a condition has held, given that it holds now or not. *)
let held_since holds since ~at_ms =
  match (holds, since) with
  | false, _ -> None
  | true, Some _ -> since
  | true, None -> Some at_ms

let held_for since need_ms ~at_ms =
  match since with
  | Some s -> at_ms -. s >= float_of_int need_ms
  | None -> false

let is_still t (f : Facts.t) =
  match t.rule.still with
  | Screen -> f.screen_still
  | Player -> f.player_still || f.screen_still

let observe_scene t (f : Facts.t) ~at_ms =
  let t =
    {
      t with
      first_fade = (if f.fade <> No_fade then f.fade else t.first_fade);
      fade_showing = f.fade;
      banner = t.banner || f.banner;
    }
  in
  (* A fade is never calm: a game may read a black frame as the overworld with
     no box, and black stays still. *)
  let calm = (not f.dialog) && f.fade = No_fade && f.free_control && warped t in
  let quiet = calm && is_still t f in
  let t =
    {
      t with
      calm_since = held_since calm t.calm_since ~at_ms;
      quiet_since = held_since quiet t.quiet_since ~at_ms;
    }
  in
  let over =
    held_for t.quiet_since t.rule.quiet_ms ~at_ms
    || held_for t.calm_since t.rule.calm_ms ~at_ms
  in
  if over && t.rule.end_on_quiet then (t, Done)
  else (t, Press (if f.dialog then Next else B))

let observe t (f : Facts.t) ~at_ms =
  if f.battle then ({ t with quiet_since = None; calm_since = None }, Battle)
  else observe_scene t f ~at_ms

let describe t =
  let fade =
    match (t.first_fade, t.fade_showing) with
    | No_fade, _ -> []
    | first, No_fade -> [ Fade.name first ^ " back up" ]
    | first, _ -> [ Fade.name first ^ " still down" ]
  in
  let banner = if t.banner then [ "banner read" ] else [] in
  match fade @ banner with
  | [] -> "no fade or banner"
  | parts -> String.concat ", " parts
