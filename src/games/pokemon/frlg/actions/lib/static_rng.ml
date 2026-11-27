module J = Json_field
module M = Menu_input
module R = Frlg_rng
module T = Frlg_rng.Rng_timings
module CR = Pokemon_catch.Catch_runner
module Shiny = Frlg_readers.Shiny_encounter_reader

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

type game_steps = {
  catch : Capture_plan.t -> party:int -> Capture.result;
  policy_catch : Wild_rng.policy_catch_steps option;
  shiny_at : int -> bool;
  log : string -> unit;
}

type end_ =
  | Shiny
  | Not_shiny
  | Not_shiny_intro
  | Catch_paused of string
  | Capture_ended of Capture.end_
  | Party_full

type outcome = { end_ : end_; attempts : int; capture : Capture.result option }

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

let make_policy_catch ~log ~on_miss ~timings ~visual_shiny_check ~config ~policy
    : Wild_rng.policy_catch_steps =
  let detect_shiny =
    if visual_shiny_check then
      Some (fun () -> Frlg_readers.Shiny_encounter_detector.detect ())
    else None
  in
  {
    find_encounter = find_encounter ~log timings;
    detect_shiny;
    on_miss;
    catch_battle =
      (fun () -> CR.run ~log (Battle_catch_steps.make ~log config) policy);
    finish_catch = Capture_steps.finish_catch ~log;
  }

let policy_catch_of ~log ~on_miss ~timings (plan : plan) =
  let mk = make_policy_catch ~log ~on_miss ~timings in
  match (plan.catch_mode, plan.visual_shiny_check) with
  | Wild_rng_plan.Throw_only, false -> None
  | Wild_rng_plan.Throw_only, true ->
      Some
        (mk ~visual_shiny_check:true ~config:Wild_rng_plan.default_catch_config
           ~policy:(Wild_rng_plan.throw_only_policy plan.capture))
  | Wild_rng_plan.Catch_policy { policy; config }, visual_shiny_check ->
      Some (mk ~visual_shiny_check ~config ~policy)

let legacy_catch ~log timings capture ~party =
  let spot = ref (Pacing.on_patch None) in
  let steps =
    {
      (Capture_steps.make ~log ~spot capture) with
      find_encounter = find_encounter ~log timings;
      flee = (fun () -> true);
    }
  in
  Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
      Capture.run steps capture ~party)

let live_game_steps ~log ?(on_miss = ignore) ~timings plan =
  {
    catch = legacy_catch ~log timings;
    policy_catch = policy_catch_of ~log ~on_miss ~timings plan;
    shiny_at = (fun slot -> Wild_rng_steps.shiny_at ~log ~slot);
    log;
  }

let synthetic_capture (plan : Capture_plan.t) (summary : CR.summary) :
    Capture.result =
  let species =
    match plan.target with Species s -> Some s | Uncaught _ -> None
  in
  {
    end_ = All_caught;
    encounters = 1;
    balls_thrown = summary.balls_thrown;
    caught = [ { species; destination = Party } ];
  }

let check_intro ~log (pc : Wild_rng.policy_catch_steps) =
  match pc.detect_shiny with
  | None -> true
  | Some detect ->
      let reading = detect () in
      log ("Static RNG: " ^ Shiny.format_reading reading);
      if reading.verdict = Shiny.Not_shiny then (
        pc.on_miss ();
        false)
      else true

let make_outcome ~n ?capture end_ = { end_; attempts = n; capture }

let finish_policy game_steps (pc : Wild_rng.policy_catch_steps) plan ~party ~n
    summary =
  if not (pc.finish_catch Party) then
    make_outcome ~n (Capture_ended (Failed "post-catch dialog did not return"))
  else
    let cap = synthetic_capture plan summary in
    let end_ = if game_steps.shiny_at (party + 1) then Shiny else Not_shiny in
    make_outcome ~n ~capture:cap end_

let of_catch_outcome game_steps pc plan ~party ~n = function
  | CR.Caught summary -> finish_policy game_steps pc plan ~party ~n summary
  | CR.Paused { reason; _ } -> make_outcome ~n (Catch_paused reason)
  | CR.No_balls _ -> make_outcome ~n (Capture_ended (Out_of_balls None))
  | CR.Foe_ended _ ->
      make_outcome ~n (Capture_ended (Failed "foe ended battle"))
  | CR.Failed { reason; _ } -> make_outcome ~n (Capture_ended (Failed reason))

let one_policy_attempt game_steps (pc : Wild_rng.policy_catch_steps) plan ~party
    ~n =
  if not (pc.find_encounter ()) then
    make_outcome ~n (Capture_ended No_encounter)
  else if not (check_intro ~log:game_steps.log pc) then
    make_outcome ~n Not_shiny_intro
  else of_catch_outcome game_steps pc plan ~party ~n (pc.catch_battle ())

let one_legacy_attempt game_steps plan ~party ~n =
  let r = game_steps.catch { plan with max_encounters = 1 } ~party in
  match r.end_ with
  | All_caught ->
      let end_ = if game_steps.shiny_at (party + 1) then Shiny else Not_shiny in
      make_outcome ~n ~capture:r end_
  | e -> make_outcome ~n ~capture:r (Capture_ended e)

let is_retryable = function Not_shiny | Not_shiny_intro -> true | _ -> false

let run game_steps ~attempts (plan : Capture_plan.t) ~party =
  if party >= Capture.party_size then make_outcome ~n:0 Party_full
  else
    let attempt n =
      match game_steps.policy_catch with
      | Some pc -> one_policy_attempt game_steps pc plan ~party ~n
      | None -> one_legacy_attempt game_steps plan ~party ~n
    in
    let rec loop n =
      let outcome = attempt n in
      if n < attempts && is_retryable outcome.end_ then loop (n + 1)
      else outcome
    in
    loop 1

let failure_code = function
  | Shiny -> None
  | Not_shiny -> Some "static_rng_not_shiny"
  | Not_shiny_intro -> Some "static_rng_not_shiny_intro"
  | Catch_paused _ -> Some "static_rng_catch_paused"
  | Capture_ended e -> Some ("static_rng_" ^ Capture.end_name e)
  | Party_full -> Some "static_rng_party_full"

let message r =
  match r.end_ with
  | Shiny ->
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
