open Grid_trace

type t = {
  mover : Grid_geometry.Direction.t -> int -> Wire.command list;
  interrupts : Leg_interrupt.t list;
  log : string -> unit;
  tracer : Leg_tracer.t option;
}

exception Interrupted_too_often of string

let default_max_interruptions = 5

(* How soon after a hold starts a sign's message shows, at the latest, when the
   hold bumps into it: about two walking tiles, however fast the player moves.
   Running, 3 tiles were 399ms, and the Pallet Town sign spoke 353 to 726ms
   into each hold south, which was held into it 6 times (Switch,
   2026-11-13 18:29, 12.03 pallet_shore). *)
let blocked_message_window_ms = 800

(* A message on the way lags the step that set it off by about two tiles, so
   one within three tiles of a hold is from its first steps. *)
let blocked_window_tiles = 3

type held = { interrupt : Leg_interrupt.t; elapsed_ms : int }

let log walker fmt = Printf.ksprintf (fun s -> walker.log ("Leg: " ^ s)) fmt
let trace walker f = Option.iter f walker.tracer

let first_seen walker m =
  List.find_opt (fun (i : Leg_interrupt.t) -> i.seen m) walker.interrupts

let record_hold walker walked_ms =
  trace walker (fun tracer ->
      Leg_tracer.walked tracer
        { chunks = 0; walked_ms; wild_battles = 0; tapped = None })

(* Holds the leg's direction for [hold_ms]; the interrupt seen first, if one
   stopped the hold. *)
let hold walker ~hold_watchers (leg : Leg_spec.t) hold_ms =
  let start = Effects.now () in
  let seen = ref None in
  let stop m =
    List.iter (fun w -> Watch_along.see w m) hold_watchers;
    seen := first_seen walker m;
    Option.is_some !seen
  in
  let raced = Effects.race (walker.mover leg.direction hold_ms) ~stop in
  match (raced, !seen) with
  | Effects.Stopped m, Some interrupt ->
      let elapsed_ms = Float.to_int (Float.round (m.t_ms -. start)) in
      record_hold walker elapsed_ms;
      trace walker (fun tracer -> Leg_tracer.interrupted tracer interrupt.kind);
      Some { interrupt; elapsed_ms }
  | Effects.Finished _, _ | Effects.Stopped _, None ->
      record_hold walker hold_ms;
      None

(* Whether [leg], held again after an interrupt, was interrupted again soon:
   something on the way that speaks, like a sign, stops every hold. A wild
   battle is luck, however soon it comes (two in a row on Route 8's grass,
   Switch, 2026-11-24): it never says the way is blocked. *)
let blocked (leg : Leg_spec.t) ~interruptions held =
  let window =
    max (leg.tile_ms * blocked_window_tiles) blocked_message_window_ms
  in
  leg.stop_if_blocked && interruptions > 1
  && held.interrupt.kind <> Wild_battle
  && held.elapsed_ms < window

(* Whether [leg] stops at the interrupt just cleared: a blocked leg, or an
   open leg asked to stop at any. *)
let stops_here (leg : Leg_spec.t) ~interruptions held =
  blocked leg ~interruptions held || ((not leg.to_wall) && leg.stop_on_interrupt)

type progress = { remaining : int; interruptions : int; exact : bool }

let tiles_walked (leg : Leg_spec.t) held ~remaining =
  Leg_timing.tiles_before_interrupt leg ~elapsed_ms:held.elapsed_ms
    ~detection_delay_ms:held.interrupt.detection_delay_ms ~remaining

(* The leg stops at [held]; the caller finds the player again, for an open
   leg near where the timing says. *)
let stop_leg walker (leg : Leg_spec.t) progress held ~seen : Leg_spec.result =
  let stopped tiles =
    {
      Leg_spec.tiles;
      exact = false;
      interruptions = progress.interruptions;
      stopped = true;
    }
  in
  if leg.to_wall then (
    log walker "%s, stopping the leg." seen;
    stopped 0)
  else
    let tiles =
      leg.tiles - progress.remaining
      + tiles_walked leg held ~remaining:progress.remaining
    in
    log walker "%s, about %d of %d tiles walked, stopping the leg." seen tiles
      leg.tiles;
    stopped tiles

let fail fmt = Printf.ksprintf (fun s -> raise (Interrupted_too_often s)) fmt

let finished (leg : Leg_spec.t) progress : Leg_spec.result =
  {
    tiles = leg.tiles;
    exact = progress.exact;
    interruptions = progress.interruptions;
    stopped = false;
  }

(* What follows a cleared interrupt: the leg's result, or more to walk. *)
type next = Done of Leg_spec.result | Walk_on of progress

(* An open leg walks on from where the interrupt's timing puts the player. *)
let walk_on_open walker leg progress held ~seen =
  let walked = tiles_walked leg held ~remaining:progress.remaining in
  let remaining = progress.remaining - walked in
  log walker "%s, about %d tiles walked, %d to go." seen walked remaining;
  let progress = { progress with remaining; exact = false } in
  if remaining <= 0 then Done (finished leg progress) else Walk_on progress

let after_interrupt walker (leg : Leg_spec.t) progress held =
  let seen =
    Printf.sprintf "%s after %dms" held.interrupt.name held.elapsed_ms
  in
  if stops_here leg ~interruptions:progress.interruptions held then
    Done (stop_leg walker leg progress held ~seen)
  else if leg.to_wall then (
    (* The wall stops the player on the leg's last tile however far they got,
       so the leg is simply held again. *)
    log walker "%s, walking to the wall again." seen;
    Walk_on progress)
  else walk_on_open walker leg progress held ~seen

let rec walk_rest walker ~max_interruptions ~hold_watchers (leg : Leg_spec.t)
    progress =
  match
    hold walker ~hold_watchers leg (Leg_timing.hold_ms leg progress.remaining)
  with
  | None -> finished leg progress
  | Some held -> (
      let progress =
        { progress with interruptions = progress.interruptions + 1 }
      in
      if progress.interruptions > max_interruptions then
        fail "Interrupted %d times on: %s" progress.interruptions
          (Leg_spec.to_string leg);
      held.interrupt.clear ();
      match after_interrupt walker leg progress held with
      | Done result -> result
      | Walk_on progress ->
          walk_rest walker ~max_interruptions ~hold_watchers leg progress)

let walk_leg ?(max_interruptions = default_max_interruptions)
    ?(hold_watchers = []) walker (leg : Leg_spec.t) =
  walk_rest walker ~max_interruptions ~hold_watchers leg
    { remaining = leg.tiles; interruptions = 0; exact = true }

(* The interrupt seen within [watch_ms], if one is. *)
let late_interrupt walker ~watch_ms =
  let seen = ref None in
  let stop m =
    seen := first_seen walker m;
    Option.is_some !seen
  in
  match Effects.await ~timeout_ms:watch_ms stop with
  | Effects.Holds _ -> !seen
  | Effects.Timeout -> None

let clear_late walker (interrupt : Leg_interrupt.t) =
  log walker "%s at the end of the leg." interrupt.name;
  trace walker (fun tracer -> Leg_tracer.interrupted tracer interrupt.kind);
  interrupt.clear ()

let clear_late_interrupts ?(max_interruptions = default_max_interruptions)
    walker ~watch_ms =
  let rec clear_from count =
    match late_interrupt walker ~watch_ms with
    | None -> count
    | Some interrupt ->
        if count >= max_interruptions then
          fail "Interrupted %d times in a row after a leg." count;
        clear_late walker interrupt;
        clear_from (count + 1)
  in
  clear_from 0
