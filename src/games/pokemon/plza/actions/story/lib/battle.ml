module S = Steps
module L = Look
module Failure = Engine_run.Failure

let start_wait_ms = 10_000
let fight_timeout_ms = 120_000.0
let watch_ms = 1000
let miss_wait_ms = 250
let misses_before_recovery = 3
let a_hold_ms = 160
let a_release_ms = 400
let move_hold_ms = 160
let zl_hold_ms = 800
let zl_release_ms = 200
let recovery_ms = 1000
let mash_ms = 40

let never_started =
  Failure.cause "battle_never_started"
    (Printf.sprintf "no battle HUD and no move symbols under ZL within %.0f s"
       (S.seconds (float_of_int start_wait_ms)))

let locked_on steps =
  S.(steps.log)
    "[PLZA] story_battle: no battle HUD; ZL held: the move symbols showed.";
  Ok ()

(* Up to 10 s of reads: the HUD, or move symbols under a 2 s ZL. *)
let rec wait_for_start steps ~start ~waited =
  let look = S.(steps.read_screen) () in
  let start = Option.value start ~default:look.at_ms in
  let late =
    waited >= start_wait_ms || look.at_ms -. start >= float_of_int start_wait_ms
  in
  if look.home_menu then Error S.game_not_running
  else if look.battle then Ok ()
  else if late then Error never_started
  else if Lock_on.zl_until_symbols steps ~hold_ms:Lock_on.hold_ms then
    locked_on steps
  else
    wait_for_start steps ~start:(Some start) ~waited:(waited + Lock_on.hold_ms)

let rank : L.effectiveness -> int = function
  | No_effect -> 0
  | Not_very_effective -> 1
  | Effective -> 2
  | Super_effective -> 3

let move_buttons = [ Wire.X; Wire.Y; Wire.A; Wire.B ]
let move_names = [ "Top"; "Left"; "Right"; "Bottom" ]

(* The most effective move's index, the first of equals; none without one. *)
let best_move moves =
  let pick (best, i) symbol =
    match (best, symbol) with
    | _, None -> (best, i + 1)
    | None, Some s -> (Some (i, s), i + 1)
    | Some (_, b), Some s when rank s > rank b -> (Some (i, s), i + 1)
    | Some _, Some _ -> (best, i + 1)
  in
  Option.map fst (fst (List.fold_left pick (None, 0) moves))

let symbol_text : L.effectiveness option -> string = function
  | Some No_effect -> "No Effect"
  | Some Not_very_effective -> "Not Very Effective"
  | Some Effective -> "Effective"
  | Some Super_effective -> "Super Effective"
  | None -> "(Unable to Detect)"

(* The four moves' symbols, [None] for any not read. *)
let four moves = List.init 4 (fun i -> Option.join (List.nth_opt moves i))
let move_text name s = Printf.sprintf " %s: %s;" name (symbol_text s)

let log_moves steps (look : L.t) =
  S.(steps.log_detail)
    ("[PLZA] story_battle: Move Effectiveness:"
    ^ String.concat "" (List.map2 move_text move_names (four look.moves)))

(* The move in place of the watch's ZL, ZL still held: the move's button
   with ZL for 160 ms, ZL alone to 800 ms, then 200 ms released (the fork
   presses ZL for 800 ms, then 200 released, beside the move for 160 ms, then
   320 released). *)
let attack steps (look : L.t) =
  log_moves steps look;
  let buttons =
    match best_move look.moves with
    | Some i ->
        S.(steps.log)
          ("[PLZA] story_battle: Picking Move: " ^ List.nth move_names i);
        [ Wire.ZL; List.nth move_buttons i ]
    | None ->
        S.(steps.log) "[PLZA] story_battle: No moves available.";
        [ Wire.ZL ]
  in
  [
    Wire.press ~hold_ms:move_hold_ms ~cooldown_ms:0 buttons;
    Wire.press
      ~hold_ms:(zl_hold_ms - move_hold_ms)
      ~cooldown_ms:zl_release_ms [ Wire.ZL ];
  ]

(* The camera turned left while ZL is mashed, for 1 s: the fork's
   lock recovery (the right stick held from the mash's start). *)
let recover steps =
  S.(steps.log) "[PLZA] story_battle: Failed to lock on. Rotating camera...";
  let right_stick = Result.to_option (Wire.stick (-1.) 0.) in
  let tap buttons =
    Wire.press ?right_stick ~hold_ms:mash_ms ~cooldown_ms:0 buttons
  in
  (* 25 taps of 40 ms, ZL on every other one from the first: 1000 ms. *)
  S.(steps.submit_batch)
    (List.init (recovery_ms / mash_ms) (fun i ->
         tap (if i mod 2 = 0 then [ Wire.ZL ] else [])))

(* One attack: ZL held up to 1 s for the symbols, the move replacing that
   hold as they show; whether a move went. *)
let attempt_one_attack steps misses =
  match
    S.(steps.race_then)
      (Wire.press ~hold_ms:watch_ms ~cooldown_ms:0 [ Wire.ZL ])
      L.moves_shown (attack steps)
  with
  | Some _ ->
      misses := 0;
      true
  | None ->
      S.wait steps miss_wait_ms;
      incr misses;
      if !misses >= misses_before_recovery then recover steps;
      false

let no_dialogue =
  Failure.cause "battle_failed"
    "fight_story_battle(): no dialogue after the battle within the timeout."

let fight steps =
  let misses = ref 0 in
  let rec go ~deadline ~attacked =
    let look = S.(steps.read_screen) () in
    let deadline =
      Option.value deadline ~default:(look.at_ms +. fight_timeout_ms)
    in
    if look.home_menu then Error S.game_not_running
    else if look.story_dialog && attacked then (
      S.(steps.log)
        "[PLZA] story_battle: a dialogue box after the attacks: the battle is \
         over.";
      Ok ())
    else if look.at_ms > deadline then Error no_dialogue
    else if look.story_dialog || not (attempt_one_attack steps misses) then (
      if not attacked then
        S.press steps Wire.A ~hold_ms:a_hold_ms ~release_ms:a_release_ms;
      go ~deadline:(Some deadline) ~attacked)
    else go ~deadline:(Some deadline) ~attacked:true
  in
  go ~deadline:None ~attacked:false

let run steps =
  Result.bind (wait_for_start steps ~start:None ~waited:0) (fun () ->
      fight steps)
