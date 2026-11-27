module J = Json_field
module M = Menu_input
module R = Frlg_rng
module T = Frlg_rng.Rng_timings

type plan = {
  species : string;
  prize_row : int;
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
}

type game_steps = {
  claim_prize : unit -> bool;
  shiny_at : int -> bool;
  log : string -> unit;
}

type end_ = Shiny | Not_shiny | Claim_failed | Party_full
type outcome = { end_ : end_; attempts : int }

let prize_page_wait_ms = 1800
let prize_list_wait_ms = 1800
let prize_tap_hold_ms = 200
let prize_tap_release_ms = 300
let prize_confirm_release_ms = 800
let ( let* ) = Result.bind

let parse_prize_row_string ~where s =
  match int_of_string_opt (String.trim s) with
  | Some n -> n
  | None ->
      J.fail "%sprize_row is %S, not a prize row (0-%d)" where s
        (Game_corner.prize_slots - 1)

let raw_prize_row ~where args =
  match J.find "prize_row" args with
  | Some (`Int n) -> n
  | Some (`String s) -> parse_prize_row_string ~where s
  | Some _ -> J.fail "%sprize_row is not an integer or string" where
  | None -> J.fail "%smissing prize_row" where

let prize_row ~where args =
  let raw = raw_prize_row ~where args in
  if raw < 0 || raw >= Game_corner.prize_slots then
    J.fail "%sprize_row is %d, not 0..%d" where raw (Game_corner.prize_slots - 1)
  else raw

let read ~options ~(fallback : Wild_rng_plan.trainer_ids) ~where args =
  let module W = Wild_rng_plan in
  let min_advance, max_advance = W.advances ~where args in
  {
    species = J.string ~where "species" args;
    prize_row = prize_row ~where args;
    tid = W.resolved_id ~where ~options ~fallback:fallback.tid "tid" args;
    sid = W.resolved_id ~where ~options ~fallback:fallback.sid "sid" args;
    seeds =
      Option.value ~default:W.default_seeds (J.string_opt ~where "seeds" args);
    boot_offset_ms = 0;
    seed_shift =
      W.opt_int ~where ~default:0 ~low:0 ~high:W.max_id "seed_shift" args;
    ingame_offset =
      W.opt_int ~where ~default:0 ~low:(-W.max_ingame_offset)
        ~high:W.max_ingame_offset "ingame_offset" args;
    frame_model = W.frame_model ~where args;
    min_advance;
    max_advance;
    attempts =
      W.opt_int ~where ~default:W.default_attempts ~low:1 ~high:W.max_attempts
        "attempts" args;
  }

let decode ?(options = Run_options.none)
    ?(fallback = Wild_rng_plan.no_trainer_ids) args =
  Action_args.decode ~action:"gift_rng" (read ~options ~fallback) args

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
    Printf.sprintf "no shiny gift %s in %s at advances %d..%d" p.species p.seeds
      p.min_advance p.max_advance
  in
  Option.to_result ~none
    (R.Gift_target.find ~calibrations model ~delays ~seeds
       ~tid_xor_sid:(p.tid lxor p.sid) ~min_advance:p.min_advance
       ~max_advance:p.max_advance)

let prize_presses ~prize_row (t : T.t) =
  let tap =
    M.hold ~hold_ms:prize_tap_hold_ms ~cooldown_ms:prize_tap_release_ms
  in
  let downs = List.init prize_row (fun _ -> tap Wire.Down) in
  let wait_ms = max 0 (t.ingame_delay_ms - T.gift_fixed_duration_ms) in
  [
    M.hold ~hold_ms:prize_tap_hold_ms ~cooldown_ms:prize_page_wait_ms Wire.A;
    M.hold ~hold_ms:prize_tap_hold_ms ~cooldown_ms:prize_list_wait_ms Wire.A;
  ]
  @ downs
  @ [
      M.hold ~hold_ms:prize_tap_hold_ms ~cooldown_ms:wait_ms Wire.A;
      M.hold ~hold_ms:prize_tap_hold_ms ~cooldown_ms:prize_confirm_release_ms
        Wire.A;
    ]

let blind_presses ~prize_row t =
  Wild_rng_steps.title_presses t @ prize_presses ~prize_row t

let live_game_steps ~log ~prize_row timings =
  let claim_prize () =
    let seq = Effects.reset () in
    log (Printf.sprintf "Gift RNG: reset (seq %d), claiming prize." seq);
    ignore (Effects.submit (blind_presses ~prize_row timings) : Wire.batch_done);
    M.settle_back ~label:"gift rng prize" ~log;
    true
  in
  {
    claim_prize;
    shiny_at = (fun slot -> Wild_rng_steps.shiny_at ~log ~slot);
    log;
  }

let run game_steps ~attempts ~party =
  if party >= Capture.party_size then { end_ = Party_full; attempts = 0 }
  else
    let rec loop n =
      if n > attempts then { end_ = Not_shiny; attempts = n - 1 }
      else if not (game_steps.claim_prize ()) then
        { end_ = Claim_failed; attempts = n }
      else if game_steps.shiny_at (party + 1) then
        { end_ = Shiny; attempts = n }
      else loop (n + 1)
    in
    loop 1

let failure_code = function
  | Shiny -> None
  | Not_shiny -> Some "gift_rng_not_shiny"
  | Claim_failed -> Some "gift_rng_claim_failed"
  | Party_full -> Some "gift_rng_party_full"

let message r =
  match r.end_ with
  | Shiny ->
      Printf.sprintf "Gift RNG: the claimed prize is shiny (attempt %d)."
        r.attempts
  | Not_shiny ->
      Printf.sprintf
        "Gift RNG: the claimed prize is not shiny after %d attempt(s)."
        r.attempts
  | Claim_failed -> "Gift RNG: prize claim sequence did not complete."
  | Party_full ->
      "Gift RNG: the party is full; the prize's summary needs a slot."
