module S = Steps
module W = Plza_walk.Wild_zone_one
module Failure = Engine_run.Failure

let max_throws = 12
let look_ms = 250
let full_party = 5
let l_hold_ms = 100
let l_release_ms = 150
let off_rocks_ms = 900
let off_rocks_release_ms = 300

let log steps fmt =
  Printf.ksprintf (fun s -> S.(steps.log) ("[PLZA] catch_in_zone: " ^ s)) fmt

let read_party_slots steps =
  let looks = ref 0 in
  let read () =
    if !looks > 0 then S.wait steps look_ms;
    incr looks;
    S.(steps.read_party_slots) ()
  in
  let slots = Catch_plan.settled_party_slots read in
  (match slots with
  | None -> log steps "the party bar did not read within 2 s"
  | Some n ->
      log steps "the party bar shows %d filled slots, steady after %d looks" n
        !looks);
  slots

(* Off its start, as a start check is: a reload puts it right. *)
let off_the_rocks_start pin_text =
  let r = W.rocks.pin in
  Failure.cause "chain_off_start"
    (Printf.sprintf
       "rocks not left: the pin at the start was %s, not within %.0f of (%.0f, \
        %.0f)"
       pin_text W.rocks_radius r.x r.y)

let off_the_rocks steps =
  S.press steps Wire.L ~hold_ms:l_hold_ms ~release_ms:l_release_ms;
  S.(steps.submit)
    (Wire.press
       ?left_stick:(Result.to_option (Wire.stick (-1.) 0.))
       ~hold_ms:off_rocks_ms ~cooldown_ms:off_rocks_release_ms [])

let go_to_spot_100 steps =
  let walk = S.walk_game_steps steps in
  let r = W.rocks in
  log steps "at the start, %s is put at (%.0f, %.0f) on the map" r.name r.pin.x
    r.pin.y;
  let pin = Plza_walk.Map_walk.read_pin walk in
  let pin_text = Option.fold ~none:"not read" ~some:W.point_text pin in
  if not (Option.fold ~none:false ~some:W.near_rocks pin) then (
    log steps "pin at the start %s, not within %.0f of (%.0f, %.0f): stop"
      pin_text W.rocks_radius r.pin.x r.pin.y;
    Error (off_the_rocks_start pin_text))
  else (
    log steps "pin at the start %s: off the rocks to the spot" pin_text;
    off_the_rocks steps;
    Plza_walk.Map_walk.walk_legs walk [ W.road_entry; W.spot_100 ])

let short ~slots ~party ~throws ~spot =
  Failure.cause "short_of_species"
    (match slots with
    | Some n ->
        Printf.sprintf "the party holds %d species of %d (%d throws at %s)" n
          party throws spot
    | None -> Printf.sprintf "no catch at %s in %d throws" spot throws)

let slots_text = Option.fold ~none:"unread" ~some:string_of_int

let catch_there steps ~slots ~party ~spot ~max_throws =
  let r = Zone_throws.catch_at_stop steps ~spot ~max_throws ~party in
  let slots =
    if r.party_reached then Some party
    else if r.throws > 0 then read_party_slots steps
    else slots
  in
  let done_ = Option.fold ~none:r.caught ~some:(fun n -> n >= party) slots in
  log steps "%d throws at %s, caught=%b, party_slots=%s/%d: %s" r.throws spot
    r.caught (slots_text slots) party
    (if done_ then "done" else "short");
  if done_ then Ok () else Error (short ~slots ~party ~throws:r.throws ~spot)

let ( let* ) = Result.bind

let run steps ~max_throws =
  let slots = read_party_slots steps in
  match slots with
  | Some n when n >= full_party ->
      log steps "the party already holds 5 species: nothing to catch";
      Ok ()
  | Some n when n >= full_party - 1 ->
      let spot = W.spot_80.name in
      log steps "party holds %d species: walking to %s for 5" n spot;
      let* () =
        Plza_walk.Map_walk.walk_legs (S.walk_game_steps steps) [ W.spot_80 ]
      in
      catch_there steps ~slots ~party:full_party ~spot ~max_throws
  | Some _ | None ->
      let* () = go_to_spot_100 steps in
      catch_there steps ~slots ~party:(full_party - 1) ~spot:W.spot_100.name
        ~max_throws
