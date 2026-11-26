module B = Switch_home.Black_screen
module H = Switch_home.Held_screen
module P = Switch_home.Switch_presses
module String_map = Map.Make (String)

let ( let* ) = Result.bind
let btn_hold_ms = 120
let nav_hold_ms = 110
let nav_wait_ms = 180
let map_open_wait_ms = 1500
let clamp_hold_ms = 2200
let clamp_wait_ms = 250
let fly_confirm_wait_ms = 1000
let fly_fade_timeout_ms = 15_000
let post_fly_settle_ms = 1200
let black_hold_ms = 80.
let clear_hold_ms = 250.
let oreburgh_city = "Oreburgh City"
let celestic_town = "Celestic Town"
let ramanas_park = "Ramanas Park"

(* Calibrated on Console A from top-left hold-clamp (Up 2200ms, Left 2200ms).
   Extend with remaining Sinnoh towns from BDSP Town Map data / decomp. *)
let oreburgh_x = 10
let oreburgh_y = 14
let celestic_x = 14
let celestic_y = 7
let ramanas_x = 9
let ramanas_y = 20

let known_towns =
  [
    (oreburgh_city, (oreburgh_x, oreburgh_y));
    (celestic_town, (celestic_x, celestic_y));
    (ramanas_park, (ramanas_x, ramanas_y));
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
  match H.wait_for ~timeout_ms (H.held black_hold_ms is_black) with
  | None -> Error (label ^ ": timed out waiting for fade to black")
  | Some () -> (
      match H.wait_for ~timeout_ms (H.held clear_hold_ms is_not_black) with
      | Some () -> Ok ()
      | None -> Error (label ^ ": timed out waiting for scene after fade"))

let tap_repeat btn n =
  for _ = 1 to n do
    P.press ~hold_ms:nav_hold_ms ~cooldown_ms:nav_wait_ms btn
  done

let fly_to ~log ~picture town () =
  match coordinates town with
  | None -> Error ("Fly.fly_to: unknown Sinnoh destination " ^ town)
  | Some (right_taps, down_taps) ->
      log ("Opening Town Map to fly to " ^ town ^ "...");
      let* () = Bdsp_overworld.open_menu ~log ~picture () in
      P.press ~hold_ms:btn_hold_ms ~cooldown_ms:map_open_wait_ms Wire.Plus;
      P.press ~hold_ms:clamp_hold_ms ~cooldown_ms:clamp_wait_ms Wire.Up;
      P.press ~hold_ms:clamp_hold_ms ~cooldown_ms:clamp_wait_ms Wire.Left;
      tap_repeat Wire.Right right_taps;
      tap_repeat Wire.Down down_taps;
      P.press ~hold_ms:btn_hold_ms ~cooldown_ms:fly_confirm_wait_ms Wire.A;
      P.press ~hold_ms:btn_hold_ms ~cooldown_ms:fly_confirm_wait_ms Wire.A;
      let* () =
        wait_fade_cycle ~picture ~timeout_ms:fly_fade_timeout_ms
          ~label:("fly_to(" ^ town ^ ")")
      in
      P.wait post_fly_settle_ms;
      log ("Arrived in " ^ town ^ ".");
      Ok ()
