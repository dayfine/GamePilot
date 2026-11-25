module S = Story_steps
module P = Catch_plan

let lock_on_wait_ms = 3000
let target_flick = 0.8
let max_views = 4
let step_ms = 500

let log_target steps what (target : P.target) =
  S.(steps.log)
    (Printf.sprintf "[PLZA] catch_in_zone: %s: plate at (%.2f, %.2f), %s" what
       target.x target.y (P.caught_text target))

type choice = { target : P.target option; saw_plates : bool }

let log_view steps cycle target =
  log_target steps
    (Printf.sprintf "target %d" (List.length (P.targets cycle)))
    target

(* Each plate read in turn, flicking right, until the cycle is over. *)
let rec read_cycle steps held cycle view flicks =
  match view with
  | Some target when flicks < max_views ->
      log_view steps cycle target;
      let cycle, more = P.add cycle target in
      if more then next_view steps held cycle flicks else cycle
  | Some _ | None -> cycle

and next_view steps held cycle flicks =
  read_cycle steps held cycle (Held_zl.flick held target_flick) (flicks + 1)

let flick_back held ~best flicks =
  let x = if flicks < 0 then -.target_flick else target_flick in
  let rec go n now = if n = 0 then now else go (n - 1) (Held_zl.flick held x) in
  go (abs flicks) (Some best)

let chosen steps held cycle best =
  let targets = P.targets cycle in
  let flicks = P.flicks_to cycle best in
  S.(steps.log)
    (Printf.sprintf
       "[PLZA] catch_in_zone: choosing target %d of %d: %d flicks %s" best
       (List.length targets) (abs flicks)
       (if flicks < 0 then "left" else "right"));
  let best = List.nth targets best in
  let now = flick_back held ~best flicks in
  (match now with
  | Some n when not (P.same n best) ->
      log_target steps "the lock moved on to another plate" n
  | Some _ | None -> ());
  Some (Option.value now ~default:best)

(* Up to 4 plates read by flicking right (0.8), then flicks back to the nearest
    one not marked caught: the closer one is much more likely to be caught. *)
let choose_target steps held =
  let view = Held_zl.wait_for_plate held ~limit_ms:lock_on_wait_ms in
  if Option.is_none view then
    S.(steps.log)
      (Printf.sprintf
         "[PLZA] catch_in_zone: ZL held %d ms, but no name plate: no lock on"
         lock_on_wait_ms);
  let cycle = read_cycle steps held (P.cycle ~max_views) view 0 in
  let targets = P.targets cycle in
  let saw_plates = targets <> [] in
  match P.nearest_uncaught targets with
  | None ->
      S.(steps.log)
        (Printf.sprintf
           "[PLZA] catch_in_zone: %d plates read, none of a species not caught"
           (List.length targets));
      { target = None; saw_plates }
  | Some best -> { target = chosen steps held cycle best; saw_plates }

let plate_went steps n =
  S.(steps.log)
    (Printf.sprintf
       "[PLZA] catch_in_zone: the plate went after %d steps toward the target" n)

let approached steps n target =
  log_target steps (Printf.sprintf "after %d steps toward the target" n) target;
  target

let step held =
  Held_zl.hold held ~ms:step_ms ~right_x:0. ~left_y:1.;
  Held_zl.read held

let approach steps held target ~misses =
  let rec go target n =
    if not (P.step_toward target ~misses ~steps:n) then
      approached steps n target
    else
      match step held with
      | Some view -> go view (n + 1)
      | None ->
          plate_went steps (n + 1);
          target
  in
  go target 0

let choose_and_approach steps =
  let held = Held_zl.start steps in
  let choice = choose_target steps held in
  {
    choice with
    target = Option.map (fun t -> approach steps held t ~misses:0) choice.target;
  }
