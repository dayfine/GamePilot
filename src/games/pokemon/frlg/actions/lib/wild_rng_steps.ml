module M = Menu_input
module T = Frlg_rng.Rng_timings

(* The fork's press lengths (ms). *)
let seed_hold_ms = 3000
let tap_ms = 50
let continue_release_ms = 1450
let recap_release_ms = 2450
let menu_hold_ms = 200
let menu_release_ms = 300
let party_open_ms = 1000
let sweet_scent_release_ms = 800
let battle_timeout_ms = 20000
let star_timeout_ms = 1000
let hold = M.hold

(* set_seed_after_delay and load_game_after_delay. *)
let title_presses (t : T.t) =
  [
    Wire.Wait { wait_ms = t.seed_delay_ms };
    hold ~hold_ms:seed_hold_ms ~cooldown_ms:0 Wire.A;
    Wire.Wait { wait_ms = t.csf_delay_ms - seed_hold_ms };
    hold ~hold_ms:tap_ms ~cooldown_ms:continue_release_ms Wire.A;
    hold ~hold_ms:tap_ms ~cooldown_ms:recap_release_ms Wire.B;
  ]

(* use_sweet_scent: the last party slot's menu, Sweet Scent after the wait. *)
let sweet_scent_presses (t : T.t) =
  let menu = hold ~hold_ms:menu_hold_ms ~cooldown_ms:menu_release_ms in
  [
    menu Wire.Start;
    menu Wire.Down;
    hold ~hold_ms:menu_hold_ms ~cooldown_ms:party_open_ms Wire.A;
    menu Wire.Up;
    menu Wire.Up;
    menu Wire.A;
    hold ~hold_ms:menu_hold_ms
      ~cooldown_ms:(t.ingame_delay_ms - T.sweet_scent_fixed_duration_ms)
      Wire.Down;
    hold ~hold_ms:menu_hold_ms ~cooldown_ms:sweet_scent_release_ms Wire.A;
  ]

let blind_presses t = title_presses t @ sweet_scent_presses t

let find_encounter ~log t () =
  let seq = Effects.reset () in
  log (Printf.sprintf "Wild RNG: reset (seq %d), the blind presses." seq);
  ignore (Effects.submit (blind_presses t) : Wire.batch_done);
  match
    Effects.await ~timeout_ms:battle_timeout_ms
      Frlg_readers.Battle_screen.battle_shows
  with
  | Holds _ -> true
  | Timeout -> false

let game_steps ~log t plan =
  let spot = ref (Pacing.on_patch None) in
  {
    (Capture_steps.make ~log ~spot plan) with
    find_encounter = find_encounter ~log t;
    flee = (fun () -> true);
  }

let read_star () =
  match
    Effects.await ~timeout_ms:star_timeout_ms Frlg_readers.Shiny_star.shiny
  with
  | Holds _ -> true
  | Timeout -> false

let shiny_at ~log ~slot =
  Effects.with_probes
    (Frlg_readers.Summary_screen.probes @ Frlg_readers.Shiny_star.probes)
    (fun () ->
      Summary_moves.open_summary slot;
      let shiny = read_star () in
      log
        (Printf.sprintf "Wild RNG: slot %d's summary %s the shiny star." slot
           (if shiny then "shows" else "does not show"));
      M.close_to_overworld ~label:"summary" ~log;
      shiny)
