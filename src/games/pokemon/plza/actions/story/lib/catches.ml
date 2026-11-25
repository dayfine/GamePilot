module S = Story_steps
module L = Story_look
module Failure = Engine_run.Failure

let story_throw =
  {
    Ball_throw.default with
    lock_on_ms = 500;
    aim_ms = 1500;
    after_throw_ms = 8000;
  }

let lines_quiet_ms = 3000
let lines_limit_ms = 30000
let max_attacks = 12
let landed_enough = 3
let misses_before_send = 2
let max_sends = 2
let up_hold_ms = 100
let up_release_ms = 2000
let a_hold_ms = 160
let a_release_ms = 840
let sweep_stick_x = 0.5
let sweep_rounds = 8

let lines steps =
  Press_through_lines.run steps ~quiet_ms:lines_quiet_ms
    ~limit_ms:lines_limit_ms

let wild_battle_on steps = L.wild_battle_on (S.(steps.read_screen) ())

let send_partner steps =
  S.press steps Wire.Up ~hold_ms:up_hold_ms ~release_ms:up_release_ms

(* Two misses in a row: D-pad up (at most twice), and a fresh count. *)
let after_misses steps ~sends =
  if sends < max_sends then (
    S.(steps.log)
      "[PLZA] weaken_target: no lock-on twice: D-pad up to send the partner out";
    send_partner steps;
    sends + 1)
  else sends

let weaken_target steps =
  let rec go ~tries ~landed ~misses ~sends =
    if tries >= max_attacks || landed >= landed_enough then landed
    else if Story_battle.attempt_one_attack steps misses then (
      misses := 0;
      go ~tries:(tries + 1) ~landed:(landed + 1) ~misses ~sends)
    else if !misses < misses_before_send then
      go ~tries:(tries + 1) ~landed ~misses ~sends
    else
      let sends = after_misses steps ~sends in
      go ~tries:(tries + 1) ~landed ~misses:(ref 0) ~sends
  in
  go ~tries:0 ~landed:0 ~misses:(ref 0) ~sends:0

let throw steps = Ball_throw.throw steps story_throw

let broke_out steps throws =
  let landed = weaken_target steps in
  S.(steps.log)
    (Printf.sprintf
       "[PLZA] catch_tutorial: throw %d broke out into a battle: %d attacks \
        landed"
       throws landed);
  ignore (lines steps : Press_through_lines.passed)

let no_catch max_throws =
  Error
    (Failure.cause "no_catch"
       (Printf.sprintf "no tutorial card after %d throws" max_throws))

(* One throw and its lines: whether its tutorial card showed. *)
let throw_caught steps throws =
  throw steps;
  let card = (lines steps).card in
  if card then
    S.(steps.log)
      (Printf.sprintf "[PLZA] catch_tutorial: caught on throw %d" throws);
  card

let catch_tutorial steps ~max_throws =
  let rec go throws =
    if throws > max_throws then no_catch max_throws
    else if throw_caught steps throws then Ok ()
    else (
      if throws < max_throws && wild_battle_on steps then broke_out steps throws;
      go (throws + 1))
  in
  go 1

(* A round with no attack landed, after the first: [None] goes on to the
   throw; [Some true] caught; [Some false] the round ends. *)
let sweep steps round =
  S.(steps.log)
    (Printf.sprintf
       "[PLZA] battle_then_catch: nothing to lock on in round %d, still in \
        battle: sweeping camera"
       round);
  if Lock_on_sweep.run steps ~camera_x:sweep_stick_x ~rounds:sweep_rounds then
    None
  else Some false

let nothing_landed steps round =
  if wild_battle_on steps then sweep steps round
  else (
    S.(steps.log)
      (Printf.sprintf
         "[PLZA] battle_then_catch: nothing to lock on in round %d: caught"
         round);
    Some true)

let throw_round steps round landed =
  ignore (lines steps : Press_through_lines.passed);
  throw steps;
  ignore (lines steps : Press_through_lines.passed);
  S.(steps.log)
    (Printf.sprintf
       "[PLZA] battle_then_catch: round %d: %d attacks landed, then a throw"
       round landed)

let battle_then_catch steps ~max_rounds =
  S.press steps Wire.A ~hold_ms:a_hold_ms ~release_ms:a_release_ms;
  ignore (lines steps : Press_through_lines.passed);
  send_partner steps;
  let rec go round =
    if round >= max_rounds then
      Error
        (Failure.cause "still_a_target"
           (Printf.sprintf "a target still locks on after %d rounds" max_rounds))
    else
      let landed = weaken_target steps in
      let verdict =
        if landed = 0 && round > 0 then nothing_landed steps (round + 1)
        else None
      in
      match verdict with
      | Some true -> Ok ()
      | Some false -> go (round + 1)
      | None ->
          throw_round steps (round + 1) landed;
          go (round + 1)
  in
  go 0
