open Frlg_readers

let probes = Screen_facts.probes @ Start_menu.probes
let max_still_change = 3.0

(* A B press, as the fork's story steps press text. *)
let press_hold_ms = 160

let middle m =
  Option.map
    (fun (s : Solid_color.stats) -> s.mean)
    (Solid_color.read m Screen_facts.fade_id)

let moved (a : Wire.rgb) (b : Wire.rgb) =
  Float.abs (a.r -. b.r) +. Float.abs (a.g -. b.g) +. Float.abs (a.b -. b.b)

(* The overworld, no box and no battle, and the step's arrival read holds. *)
let arrived_at ~arrived (seen : Screen_state.Facts.t) m =
  seen.fade = No_fade && (not seen.dialog) && (not seen.battle) && arrived m

module Fade_in = Frlg_overworld.Warp_fade_in

(* A fade still coming up, when the settle waits fade-ins out: the game takes
   no input yet, so it is no free control. *)
let fading_in = function Some w -> Fade_in.fading w | None -> false

let facts ~menu_open ~arrived ~fade_in ~last m : Screen_state.Facts.t =
  let seen = Screen_facts.of_measurements m in
  let free_control =
    seen.fade = No_fade && (not seen.dialog) && (not seen.battle)
    && (not (Start_menu.start_menu_open m))
    && (not (menu_open m))
    && not (fading_in fade_in)
  in
  let screen_still =
    match (last, middle m) with
    | Some a, Some b -> moved a b < max_still_change
    | _ -> false
  in
  { seen with free_control; screen_still; arrived = arrived_at ~arrived seen m }

let see_fade_in fade_in m =
  Option.iter (fun w -> Fade_in.watch_frame w m) fade_in

let look ~menu_open ~arrived ~fade_in last () : Screen_state.Settle.look =
  match Effects.read () with
  | None ->
      {
        facts = Screen_state.Facts.none;
        at_ms = Effects.now ();
        since_ms = None;
      }
  | Some m ->
      see_fade_in fade_in m;
      let facts = facts ~menu_open ~arrived ~fade_in ~last:!last m in
      last := middle m;
      { facts; at_ms = m.t_ms; since_ms = None }

let press_b () = Wire.press ~hold_ms:press_hold_ms ~cooldown_ms:0 [ Wire.B ]

let warp_look ~arrived m : Screen_state.Settle.look option =
  let seen = Screen_facts.of_measurements m in
  let facts = { seen with arrived = arrived_at ~arrived seen m } in
  if Screen_state.Facts.shows_warp facts then
    Some { facts; at_ms = m.t_ms; since_ms = None }
  else None

(* Runs [commands] watching every frame, each fed to [fade_in]; the first that
   showed a warp. The stop never holds: the batch runs to its end. *)
let watch ?fade_in ~arrived commands =
  let seen = ref None in
  let note m =
    see_fade_in fade_in m;
    if Option.is_none !seen then seen := warp_look ~arrived m;
    false
  in
  ignore (Effects.race commands ~stop:note : Effects.raced);
  !seen

(* B, then the wait; only the wait while a fade-in is still coming up. *)
let press ~arrived ~fade_in (_ : Screen_state.Talk_over.press) ~wait_ms =
  let wait = Wire.Wait { wait_ms } in
  let commands = if fading_in fade_in then [ wait ] else [ press_b (); wait ] in
  watch ?fade_in ~arrived commands

let never _ = false

let io ?(menu_open = never) ?(arrived = never) ?(await_fade_in = false)
    ~flee_battle ~log () : Screen_state.Settle.io =
  let last = ref None in
  let fade_in = if await_fade_in then Some (Fade_in.watch ()) else None in
  {
    look = look ~menu_open ~arrived ~fade_in last;
    press = press ~arrived ~fade_in;
    flee_battle;
    log;
  }

(* The settle's own outcome, with {!probes} subscribed and no battle fled. *)
let run_settle ?menu_open ?arrived ?await_fade_in ?(start = []) kind ~label ~log
    =
  let io =
    io ?menu_open ?arrived ?await_fade_in ~flee_battle:(fun () -> false) ~log ()
  in
  let arrived = Option.value arrived ~default:never in
  Effects.with_probes probes (fun () ->
      let seen = if start = [] then None else watch ~arrived start in
      Screen_state.Settle.run ?seen (Screen_state.Settle.rule kind) ~label io)

let settle ?menu_open ?arrived ?await_fade_in ?start kind ~label ~battle_ends
    ~log =
  match
    run_settle ?menu_open ?arrived ?await_fade_in ?start kind ~label ~log
  with
  | Quiet _ -> Ok ()
  | Battle what when battle_ends ->
      log (label ^ ": a battle starts, " ^ what);
      Ok ()
  | Battle what ->
      Error (Pokemon_checkpoints.Failure.cause "battle" (label ^ ": " ^ what))
  | Timed_out why -> Error (Pokemon_checkpoints.Failure.cause "not_settled" why)

let until_battle ~label ~log =
  match run_settle Talk ~label ~log with
  | Battle what ->
      log (label ^ ": a battle starts, " ^ what);
      Ok ()
  | Quiet why ->
      Error
        (Pokemon_checkpoints.Failure.cause "no_battle"
           (label ^ ": the overworld went quiet with no battle (" ^ why ^ ")"))
  | Timed_out why -> Error (Pokemon_checkpoints.Failure.cause "not_settled" why)
