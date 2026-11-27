module B = Switch.Black_screen
module H = Screen_graph.Held_screen
module P = Switch.Switch_presses
module String_map = Map.Make (String)

let ( let* ) = Result.bind

type press_timing = {
  btn_hold_ms : int;
  nav_hold_ms : int;
  nav_wait_ms : int;
  map_open_wait_ms : int;
  clamp_hold_ms : int;
  clamp_wait_ms : int;
  confirm_wait_ms : int;
}

type fade_timing = {
  timeout_ms : int;
  post_settle_ms : int;
  black_hold_ms : float;
  clear_hold_ms : float;
}

let press_t =
  {
    btn_hold_ms = 120;
    nav_hold_ms = 110;
    nav_wait_ms = 180;
    map_open_wait_ms = 1500;
    clamp_hold_ms = 2200;
    clamp_wait_ms = 250;
    confirm_wait_ms = 1000;
  }

let fade_t =
  {
    timeout_ms = 15_000;
    post_settle_ms = 1200;
    black_hold_ms = 80.;
    clear_hold_ms = 250.;
  }

let oreburgh_city = "Oreburgh City"
let celestic_town = "Celestic Town"
let ramanas_park = "Ramanas Park"

type town_pos = { right_taps : int; down_taps : int }

let pair_of pos = (pos.right_taps, pos.down_taps)

(* Calibrated on Console A from top-left hold-clamp (Up 2200ms, Left 2200ms).
   Extend with remaining Sinnoh towns from BDSP Town Map data / decomp. *)
let known_towns =
  [
    (oreburgh_city, pair_of { right_taps = 10; down_taps = 14 });
    (celestic_town, pair_of { right_taps = 14; down_taps = 7 });
    (ramanas_park, pair_of { right_taps = 9; down_taps = 20 });
  ]

let town_map =
  List.fold_left
    (fun acc (name, coords) -> String_map.add name coords acc)
    String_map.empty known_towns

let coordinates town = String_map.find_opt town town_map
let is_black m = if B.shown m then Some () else None
let is_not_black m = if not (B.shown m) then Some () else None

let wait_fade_cycle ~picture ~timeout_ms ~label =
  ignore (Effects.subscribe (B.probes ~picture) : string list);
  match H.wait_for ~timeout_ms (H.held fade_t.black_hold_ms is_black) with
  | None -> Error (label ^ ": timed out waiting for fade to black")
  | Some () -> (
      match
        H.wait_for ~timeout_ms (H.held fade_t.clear_hold_ms is_not_black)
      with
      | Some () -> Ok ()
      | None -> Error (label ^ ": timed out waiting for scene after fade"))

let tap_repeat btn n =
  for _ = 1 to n do
    P.press ~hold_ms:press_t.nav_hold_ms ~cooldown_ms:press_t.nav_wait_ms btn
  done

let fly_to_coords ~log ~picture ~town (right_taps, down_taps) =
  log ("Opening Town Map to fly to " ^ town ^ "...");
  let* () = Overworld_actions.open_menu ~log ~picture () in
  P.press ~hold_ms:press_t.btn_hold_ms ~cooldown_ms:press_t.map_open_wait_ms
    Wire.Plus;
  P.press ~hold_ms:press_t.clamp_hold_ms ~cooldown_ms:press_t.clamp_wait_ms
    Wire.Up;
  P.press ~hold_ms:press_t.clamp_hold_ms ~cooldown_ms:press_t.clamp_wait_ms
    Wire.Left;
  tap_repeat Wire.Right right_taps;
  tap_repeat Wire.Down down_taps;
  P.press ~hold_ms:press_t.btn_hold_ms ~cooldown_ms:press_t.confirm_wait_ms
    Wire.A;
  P.press ~hold_ms:press_t.btn_hold_ms ~cooldown_ms:press_t.confirm_wait_ms
    Wire.A;
  let* () =
    wait_fade_cycle ~picture ~timeout_ms:fade_t.timeout_ms
      ~label:("fly_to(" ^ town ^ ")")
  in
  P.wait fade_t.post_settle_ms;
  log ("Arrived in " ^ town ^ ".");
  Ok ()

let fly_to ~log ~picture town () =
  match coordinates town with
  | None -> Error ("Fly.fly_to: unknown Sinnoh destination " ^ town)
  | Some coords -> fly_to_coords ~log ~picture ~town coords
