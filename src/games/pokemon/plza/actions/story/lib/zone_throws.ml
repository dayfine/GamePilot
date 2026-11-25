module S = Story_steps
module P = Catch_plan

type result = { throws : int; caught : bool; party_reached : bool }

let none = { throws = 0; caught = false; party_reached = false }
let party_caught_hold_ms = 250.
let throws_at_one_target = 3
let fight_off_rounds = 3
let tries_at_stop = 4
let sweep_stick_x = 0.5
let sweep_rounds = 8
let look_right_ms = 400
let look_right_release_ms = 300
let pitch_down_ms = 1500
let pitch_down_release_ms = 100
let pitch_up_ms = 600
let pitch_up_release_ms = 300

let log steps fmt =
  Printf.ksprintf (fun s -> S.(steps.log) ("[PLZA] catch_in_zone: " ^ s)) fmt

let right_stick steps x y ~hold_ms ~release_ms =
  S.(steps.submit)
    (Wire.press
       ?right_stick:(Result.to_option (Wire.stick x y))
       ~hold_ms ~cooldown_ms:release_ms [])

(* After a lock-on the camera looks steeply down: the right stick down 1.5 s
    (released 100 ms) pins the pitch at its lowest, then up 600 ms (released
    300) gives the walking pitch. *)
let level_camera steps =
  right_stick steps 0. (-1.) ~hold_ms:pitch_down_ms
    ~release_ms:pitch_down_release_ms;
  right_stick steps 0. 1. ~hold_ms:pitch_up_ms ~release_ms:pitch_up_release_ms

(* The party bar at [party] or more on reads 250 ms apart, before [until]. *)
let rec watch_party steps ~party ~until ~since =
  let now = S.(steps.now) () in
  if now >= until then false
  else
    match S.(steps.read_party_slots) () with
    | Some n when n >= party ->
        let since = Option.value since ~default:now in
        now -. since >= party_caught_hold_ms
        || watch_party steps ~party ~until ~since:(Some since)
    | Some _ | None -> watch_party steps ~party ~until ~since:None

let throw_watched steps ~party =
  let o = Catches.story_throw in
  S.(steps.submit_batch) (Ball_throw.inputs { o with after_throw_ms = 0 });
  let until = S.(steps.now) () +. float_of_int o.after_throw_ms in
  let seen = watch_party steps ~party ~until ~since:None in
  log steps "party bar reached %d: %s" party (if seen then "yes" else "no");
  if not seen then S.(steps.wait_until) until;
  seen

let pass_lines steps = ignore (Catches.lines steps : Press_through_lines.passed)

(* One round: the attacks, the lines and a watched throw. *)
let throw_round steps out ~landed ~party =
  pass_lines steps;
  let reached = throw_watched steps ~party in
  let out = { out with throws = out.throws + 1 } in
  log steps "round %d: %d attacks landed, then a throw" out.throws landed;
  if reached then { out with caught = true; party_reached = true }
  else (
    pass_lines steps;
    out)

let weaken_then_throw steps ~max_throws ~party =
  let rec go out =
    if out.throws >= max_throws then out
    else
      let landed = Catches.weaken_target steps in
      if landed = 0 && out.throws > 0 then (
        log steps "nothing to lock on in round %d: gone" (out.throws + 1);
        out)
      else
        let out = throw_round steps out ~landed ~party in
        if out.caught then out else go out
  in
  go none

let add a b =
  {
    throws = a.throws + b.throws;
    caught = a.caught || b.caught;
    party_reached = a.party_reached || b.party_reached;
  }

let breakout_weaken steps out ~max_throws ~party =
  if out.throws >= max_throws then out
  else (
    log steps "the throw broke out: battle, weakening";
    let w =
      weaken_then_throw steps ~max_throws:(max_throws - out.throws) ~party
    in
    { w with throws = out.throws + w.throws })

type target_throws = { result : result; move_on : bool }
type after_miss = Caught | Battle | Relocked of P.target * Held_zl.t | Lost

(* After a miss and its lines: a battle, the lock back on a target, or the
   target gone (caught when its plate was not marked caught). *)
let after_miss steps (aimed : P.target) =
  if Catches.wild_battle_on steps then Battle
  else
    let held = Held_zl.start steps in
    match Held_zl.wait_for_plate held ~limit_ms:Zone_aim.lock_on_wait_ms with
    | Some relocked -> Relocked (relocked, held)
    | None when aimed.caught = Some false -> Caught
    | None -> Lost

let miss_text = function Caught -> "caught" | _ -> "miss"

let caught_on_throw steps (aimed : P.target) out ~party =
  log steps "throw %d at plate y %.2f: caught (party %d)" out.throws aimed.y
    party;
  { result = { out with caught = true; party_reached = true }; move_on = false }

let rec throw_at steps (aimed : P.target) out ~max_throws ~party =
  if out.throws >= max_throws then { result = out; move_on = false }
  else throw_once steps aimed out ~max_throws ~party

and throw_once steps aimed out ~max_throws ~party =
  let reached = throw_watched steps ~party in
  let out = { out with throws = out.throws + 1 } in
  if reached then caught_on_throw steps aimed out ~party
  else after_throw steps aimed out ~max_throws ~party

and after_throw steps aimed out ~max_throws ~party =
  pass_lines steps;
  let next = after_miss steps aimed in
  log steps "throw %d at plate y %.2f: %s" out.throws aimed.y (miss_text next);
  missed steps next out ~max_throws ~party

and missed steps next out ~max_throws ~party =
  match next with
  | Caught -> { result = { out with caught = true }; move_on = false }
  | Battle ->
      { result = breakout_weaken steps out ~max_throws ~party; move_on = false }
  | Relocked (relocked, _) when relocked.caught = Some true ->
      { result = out; move_on = false }
  | Relocked (relocked, _) when out.throws >= throws_at_one_target ->
      Zone_aim.log_target steps
        (Printf.sprintf "%d misses at one lock: stopping at this spot"
           out.throws)
        relocked;
      { result = out; move_on = true }
  | Relocked (relocked, held) ->
      Zone_aim.log_target steps "missed, locked on again" relocked;
      let aimed = Zone_aim.approach steps held relocked ~misses:out.throws in
      throw_at steps aimed out ~max_throws ~party
  | Lost -> { result = out; move_on = false }

let sweep_for_lock_on steps ~spot =
  let start = S.(steps.now) () in
  let locked =
    Lock_on_sweep.run steps ~camera_x:sweep_stick_x ~rounds:sweep_rounds
  in
  let elapsed = S.(steps.now) () -. start in
  if locked then
    log steps
      "at %s: the move symbols showed %.0f ms into the lock-on sweep: locked on"
      spot elapsed
  else
    log steps "at %s: no move symbols in %d sweep rounds (%.0f ms): L" spot
      sweep_rounds elapsed;
  locked

let rec fight_off steps round =
  if round <= fight_off_rounds then (
    let landed = Catches.weaken_target steps in
    pass_lines steps;
    let still_on = Catches.wild_battle_on steps in
    log steps "fighting off, round %d: %d attacks landed, battle %s" round
      landed
      (if still_on then "on" else "over");
    if landed > 0 && still_on then fight_off steps (round + 1))

let fight_back steps ~max_throws ~party =
  let attacker =
    Held_zl.wait_for_plate (Held_zl.start steps)
      ~limit_ms:Zone_aim.lock_on_wait_ms
  in
  Option.iter
    (Zone_aim.log_target steps "a wild battle at the stop, locked on to")
    attacker;
  match attacker with
  | Some { caught = Some true; _ } ->
      log steps "a species already caught: fighting it off, no throws";
      fight_off steps 1;
      none
  | Some _ | None ->
      log steps "a wild battle at the stop: weakening and throwing";
      weaken_then_throw steps ~max_throws ~party

(* One try at the stop: what it threw, whether to stop trying, and whether
   the camera's pitch tipped. *)
type try_ = { got : result; stop : bool }

let aim_and_throw steps ~spot ~max_throws ~party =
  if not (sweep_for_lock_on steps ~spot) then (
    log steps "no lock-on at %s in the sweep" spot;
    { got = none; stop = true })
  else
    let choice = Zone_aim.choose_and_approach steps in
    match choice.target with
    | _ when not choice.saw_plates -> { got = none; stop = false }
    | None ->
        log steps "only species already caught lock on: looking further right";
        right_stick steps sweep_stick_x 0. ~hold_ms:look_right_ms
          ~release_ms:look_right_release_ms;
        { got = none; stop = false }
    | Some target ->
        let t = throw_at steps target none ~max_throws ~party in
        { got = t.result; stop = t.move_on }

let one_try steps ~spot ~max_throws ~party =
  if Catches.wild_battle_on steps then
    { got = fight_back steps ~max_throws ~party; stop = false }
  else aim_and_throw steps ~spot ~max_throws ~party

let catch_at_stop steps ~spot ~max_throws ~party =
  let rec go tries out ~tipped =
    if tries >= tries_at_stop || out.caught || out.throws >= max_throws then
      (out, tipped)
    else (
      if tipped then level_camera steps;
      let t =
        one_try steps ~spot ~max_throws:(max_throws - out.throws) ~party
      in
      let out = add out t.got in
      if t.stop then (out, true) else go (tries + 1) out ~tipped:true)
  in
  let out, tipped = go 0 none ~tipped:false in
  if out.caught then log steps "caught at %s" spot
  else if tipped then level_camera steps;
  out
