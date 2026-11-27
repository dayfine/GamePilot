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

let max_id = 0xffff
let seed_mask = 0xffff
let default_min_advance = 900
let default_max_advance = 4000
let default_attempts = 1
let max_attempts = 99
let max_ingame_offset = 99
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

let check_id ~where name n =
  if n < 0 || n > max_id then J.fail "%s%s is %d, not 0..65535" where name n
  else n

let resolved_id ~where ~options ~fallback name args =
  match (Run_options.int options name, J.find name args, fallback) with
  | Some n, _, _ -> n
  | None, Some _, _ -> check_id ~where name (J.int ~where name args)
  | None, None, Some n -> n
  | None, None, None ->
      J.fail
        "%smissing %s (pass --options %s=N, set GAMEPILOT_FRLG_%s, or set it \
         in trainer_ids.json)"
        where name name
        (String.uppercase_ascii name)

let opt_int ~where ~default ~low ~high name args =
  match J.find name args with
  | None -> default
  | Some _ ->
      let n = J.int ~where name args in
      if n < low || n > high then
        J.fail "%s%s is %d, not %d..%d" where name n low high
      else n

let advances ~where args =
  match J.list_opt ~where "advances" args with
  | None -> (default_min_advance, default_max_advance)
  | Some [ `Int low; `Int high ] when 0 <= low && low <= high -> (low, high)
  | Some _ -> J.fail "%sadvances is not [min, max]" where

let frame_model ~where args =
  match J.string_opt ~where "frame_model" args with
  | None -> Wild_rng_plan.default_frame_model
  | Some name ->
      if Option.is_some (Wild_rng_plan.find_frame_model name) then name
      else J.fail "%sframe_model is %s, not mgba or switch" where name

let read ~options ~(fallback : Wild_rng_plan.trainer_ids) ~where args =
  let min_advance, max_advance = advances ~where args in
  {
    species = J.string ~where "species" args;
    prize_row = prize_row ~where args;
    tid = resolved_id ~where ~options ~fallback:fallback.tid "tid" args;
    sid = resolved_id ~where ~options ~fallback:fallback.sid "sid" args;
    seeds =
      Option.value ~default:Wild_rng_plan.default_seeds
        (J.string_opt ~where "seeds" args);
    boot_offset_ms = 0;
    seed_shift = opt_int ~where ~default:0 ~low:0 ~high:max_id "seed_shift" args;
    ingame_offset =
      opt_int ~where ~default:0 ~low:(-max_ingame_offset)
        ~high:max_ingame_offset "ingame_offset" args;
    frame_model = frame_model ~where args;
    min_advance;
    max_advance;
    attempts =
      opt_int ~where ~default:default_attempts ~low:1 ~high:max_attempts
        "attempts" args;
  }

let decode ?(options = Run_options.none)
    ?(fallback = Wild_rng_plan.no_trainer_ids) args =
  Action_args.decode ~action:"gift_rng" (read ~options ~fallback) args

let apply_calibration (entry : R.Switch_rng_calibration.entry) p =
  {
    p with
    boot_offset_ms = p.boot_offset_ms + entry.boot_offset_ms;
    seed_shift = (p.seed_shift + entry.seed_shift) land seed_mask;
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
