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

let facts ~last m : Screen_state.Facts.t =
  let seen = Screen_facts.of_measurements m in
  let free_control =
    seen.fade = No_fade && (not seen.dialog) && (not seen.battle)
    && not (Start_menu.start_menu_open m)
  in
  let screen_still =
    match (last, middle m) with
    | Some a, Some b -> moved a b < max_still_change
    | _ -> false
  in
  { seen with free_control; screen_still }

let look last () : Screen_state.Settle.look =
  match Effects.read () with
  | None ->
      {
        facts = Screen_state.Facts.none;
        at_ms = Effects.now ();
        since_ms = None;
      }
  | Some m ->
      let facts = facts ~last:!last m in
      last := middle m;
      { facts; at_ms = m.t_ms; since_ms = None }

let press_b () =
  Wire.Press { buttons = [ Wire.B ]; hold_ms = press_hold_ms; cooldown_ms = 0 }

let press (_ : Screen_state.Talk_over.press) ~wait_ms =
  ignore (Effects.submit [ press_b (); Wire.Wait { wait_ms } ])

let io ~flee_battle ~log : Screen_state.Settle.io =
  let last = ref None in
  { look = look last; press; flee_battle; log }

let settle kind ~label ~battle_ends ~log =
  let io = io ~flee_battle:(fun () -> false) ~log in
  match Screen_state.Settle.run (Screen_state.Settle.rule kind) ~label io with
  | Quiet _ -> Ok ()
  | Battle what when battle_ends ->
      log (label ^ ": a battle starts, " ^ what);
      Ok ()
  | Battle what -> Error (Story.Failure.cause "battle" (label ^ ": " ^ what))
  | Timed_out why -> Error (Story.Failure.cause "not_settled" why)
