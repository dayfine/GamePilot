module J = Json_field
module M = Menu_input
module R = Frlg_rng
module T = Frlg_rng.Rng_timings

type plan = {
  species : string;
  tid : int;
  sid : int;
  seeds : string;
  boot_offset_ms : int;
  seed_shift : int;
  ingame_offset : int;
  frame_model : string;
  min_advance : int;
  max_advance : int;
  attempts : int;
  capture : Capture_plan.t;
  catch_mode : Wild_rng_plan.catch_mode;
  visual_shiny_check : bool;
}

type outcome = {
  end_ : Wild_rng.end_;
  attempts : int;
  capture : Capture.result option;
}

let max_boot_offset_ms = 10000
let static_menu_hold_ms = 200
let static_menu_release_ms = 300
let static_interact_release_ms = 800
let static_mash_a_ms = 1000
let ( let* ) = Result.bind

let read ~options ~(fallback : Wild_rng_plan.trainer_ids) ~default_frame_model
    ~where args =
  let module W = Wild_rng_plan in
  let min_advance, max_advance = W.advances ~where args in
  let attempts =
    W.opt_int ~where ~default:W.default_attempts ~low:1 ~high:W.max_attempts
      "attempts" args
  in
  let cap =
    Capture_plan.read ~where args |> fun c ->
    Capture_plan.apply_options options
      { c with max_encounters = 1; catches = 1 }
  in
  {
    species = J.string ~where "species" args;
    tid = W.resolved_id ~where ~options ~fallback:fallback.tid "tid" args;
    sid = W.resolved_id ~where ~options ~fallback:fallback.sid "sid" args;
    seeds =
      Option.value ~default:W.default_seeds (J.string_opt ~where "seeds" args);
    boot_offset_ms =
      W.opt_int ~where ~default:0 ~low:(-max_boot_offset_ms)
        ~high:max_boot_offset_ms "boot_offset_ms" args;
    seed_shift =
      W.opt_int ~where ~default:0 ~low:0 ~high:W.max_id "seed_shift" args;
    ingame_offset =
      W.opt_int ~where ~default:0 ~low:(-W.max_ingame_offset)
        ~high:W.max_ingame_offset "ingame_offset" args;
    frame_model = W.frame_model ~default:default_frame_model ~where args;
    min_advance;
    max_advance;
    attempts;
    capture = cap;
    catch_mode = W.catch_mode ~where cap args;
    visual_shiny_check = W.visual_shiny_check ~where args;
  }

let decode ?(options = Run_options.none)
    ?(fallback = Wild_rng_plan.no_trainer_ids)
    ?(default_frame_model = Wild_rng_plan.default_frame_model) args =
  Action_args.decode ~action:"static_rng"
    (read ~options ~fallback ~default_frame_model)
    args

let apply_calibration (entry : R.Switch_rng_calibration.entry) p =
  {
    p with
    boot_offset_ms = p.boot_offset_ms + entry.boot_offset_ms;
    seed_shift = (p.seed_shift + entry.seed_shift) land Wild_rng_plan.seed_mask;
    ingame_offset = p.ingame_offset + entry.ingame_offset;
  }

let target p =
  let* delays, seeds =
    Wild_rng_plan.seed_column_of ~seeds:p.seeds ~seed_shift:p.seed_shift
  in
  let* model =
    Option.to_result
      ~none:("unknown frame_model " ^ p.frame_model)
      (Wild_rng_plan.find_frame_model p.frame_model)
  in
  let calibrations =
    Wild_rng_plan.calibrations_of_offsets ~boot_offset_ms:p.boot_offset_ms
      ~ingame_offset:p.ingame_offset model
  in
  let none =
    Printf.sprintf "no shiny static %s in %s at advances %d..%d" p.species
      p.seeds p.min_advance p.max_advance
  in
  Option.to_result ~none
    (R.Gift_target.find ~calibrations ~timing:T.static model ~delays ~seeds
       ~tid_xor_sid:(p.tid lxor p.sid) ~min_advance:p.min_advance
       ~max_advance:p.max_advance)

(* Open Start menu, wait the remaining in-game delay, close Start menu, talk to
   the static encounter, and mash A for 1 s to clear cry dialogue. *)
let static_presses (t : T.t) =
  let wait_ms = max 0 (t.ingame_delay_ms - T.static_fixed_duration_ms) in
  let mash_count = static_mash_a_ms / (M.tap_hold_ms + M.tap_release_ms) in
  let mash_tap =
    M.hold ~hold_ms:M.tap_hold_ms ~cooldown_ms:M.tap_release_ms Wire.A
  in
  [
    M.hold ~hold_ms:static_menu_hold_ms ~cooldown_ms:static_menu_release_ms
      Wire.Start;
    Wire.Wait { wait_ms };
    M.hold ~hold_ms:static_menu_hold_ms ~cooldown_ms:static_menu_release_ms
      Wire.B;
    M.hold ~hold_ms:static_menu_hold_ms ~cooldown_ms:static_interact_release_ms
      Wire.A;
  ]
  @ List.init mash_count (fun _ -> mash_tap)

let blind_presses t = Wild_rng_steps.title_presses t @ static_presses t

let find_encounter ~log timings () =
  let seq = Effects.reset () in
  log (Printf.sprintf "Static RNG: reset (seq %d), the blind presses." seq);
  ignore (Effects.submit (blind_presses timings) : Wire.batch_done);
  match
    Effects.await ~timeout_ms:Wild_rng_steps.battle_timeout_ms
      Frlg_readers.Battle_screen.battle_shows
  with
  | Holds _ -> true
  | Timeout -> false

let live_game_steps ~log ?(on_miss = ignore) ~timings (plan : plan) :
    Wild_rng.game_steps =
  let find_encounter = find_encounter ~log timings in
  {
    catch = Wild_rng_steps.legacy_catch ~log ~find_encounter;
    policy_catch =
      Wild_rng_steps.policy_catch_for ~log ~find_encounter ~on_miss
        ~catch_mode:plan.catch_mode ~visual_shiny_check:plan.visual_shiny_check
        plan.capture;
    shiny_at = (fun slot -> Wild_rng_steps.shiny_at ~log ~slot);
    log;
  }

let is_retryable = function
  | Wild_rng.Not_shiny | Wild_rng.Not_shiny_intro -> true
  | _ -> false

let run game_steps ~attempts (plan : Capture_plan.t) ~party =
  if party >= Capture.party_size then
    { end_ = Wild_rng.Party_full; attempts = 0; capture = None }
  else
    let single_plan = { plan with max_encounters = 1 } in
    let rec loop n =
      let r = Wild_rng.run ~label:"Static RNG" game_steps single_plan ~party in
      if n < attempts && is_retryable r.end_ then loop (n + 1)
      else { end_ = r.end_; attempts = n; capture = r.capture }
    in
    loop 1

let failure_code = function
  | Wild_rng.Shiny -> None
  | Not_shiny -> Some "static_rng_not_shiny"
  | Not_shiny_intro -> Some "static_rng_not_shiny_intro"
  | Catch_paused _ -> Some "static_rng_catch_paused"
  | Capture_ended e -> Some ("static_rng_" ^ Capture.end_name e)
  | Party_full -> Some "static_rng_party_full"

let message r =
  match r.end_ with
  | Wild_rng.Shiny ->
      Printf.sprintf "Static RNG: the catch is shiny (attempt %d)." r.attempts
  | Not_shiny ->
      Printf.sprintf "Static RNG: the catch is not shiny after %d attempt(s)."
        r.attempts
  | Not_shiny_intro ->
      Printf.sprintf
        "Static RNG: battle intro was not shiny after %d attempt(s); skipped \
         catch."
        r.attempts
  | Catch_paused reason -> "Static RNG: catch paused for user: " ^ reason ^ "."
  | Capture_ended e ->
      "Static RNG: the capture ended " ^ Capture.end_name e ^ "."
  | Party_full ->
      "Static RNG: the party is full; the catch's summary needs a slot."
