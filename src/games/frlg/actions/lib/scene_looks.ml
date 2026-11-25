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

let facts ~menu_open ~arrived ~last m : Screen_state.Facts.t =
  let seen = Screen_facts.of_measurements m in
  let free_control =
    seen.fade = No_fade && (not seen.dialog) && (not seen.battle)
    && (not (Start_menu.start_menu_open m))
    && not (menu_open m)
  in
  let screen_still =
    match (last, middle m) with
    | Some a, Some b -> moved a b < max_still_change
    | _ -> false
  in
  { seen with free_control; screen_still; arrived = arrived_at ~arrived seen m }

let look ~menu_open ~arrived last () : Screen_state.Settle.look =
  match Effects.read () with
  | None ->
      {
        facts = Screen_state.Facts.none;
        at_ms = Effects.now ();
        since_ms = None;
      }
  | Some m ->
      let facts = facts ~menu_open ~arrived ~last:!last m in
      last := middle m;
      { facts; at_ms = m.t_ms; since_ms = None }

let press_b () =
  Wire.Press { buttons = [ Wire.B ]; hold_ms = press_hold_ms; cooldown_ms = 0 }

let warp_look ~arrived m : Screen_state.Settle.look option =
  let seen = Screen_facts.of_measurements m in
  let facts = { seen with arrived = arrived_at ~arrived seen m } in
  if Screen_state.Facts.shows_warp facts then
    Some { facts; at_ms = m.t_ms; since_ms = None }
  else None

(* Runs [commands] watching every frame; the first that showed a warp. The
   stop never holds: the batch runs to its end. *)
let watch ~arrived commands =
  let seen = ref None in
  let note m =
    if Option.is_none !seen then seen := warp_look ~arrived m;
    false
  in
  ignore (Effects.race commands ~stop:note : Effects.raced);
  !seen

let press ~arrived (_ : Screen_state.Talk_over.press) ~wait_ms =
  watch ~arrived [ press_b (); Wire.Wait { wait_ms } ]

let never _ = false

let io ?(menu_open = never) ?(arrived = never) ~flee_battle ~log () :
    Screen_state.Settle.io =
  let last = ref None in
  {
    look = look ~menu_open ~arrived last;
    press = press ~arrived;
    flee_battle;
    log;
  }

let settle ?menu_open ?arrived ?(start = []) kind ~label ~battle_ends ~log =
  let io = io ?menu_open ?arrived ~flee_battle:(fun () -> false) ~log () in
  let arrived = Option.value arrived ~default:never in
  match
    Effects.with_probes probes (fun () ->
        let seen = if start = [] then None else watch ~arrived start in
        Screen_state.Settle.run ?seen (Screen_state.Settle.rule kind) ~label io)
  with
  | Quiet _ -> Ok ()
  | Battle what when battle_ends ->
      log (label ^ ": a battle starts, " ^ what);
      Ok ()
  | Battle what ->
      Error (Checkpoints_run.Failure.cause "battle" (label ^ ": " ^ what))
  | Timed_out why -> Error (Checkpoints_run.Failure.cause "not_settled" why)
