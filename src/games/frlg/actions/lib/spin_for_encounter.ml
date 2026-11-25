open Frlg_readers
module M = Menu_input

let batch_turns = 24
let turn_hold_ms = 30
let turn_release_ms = 100

let clockwise : Grid_maps.Direction.t -> Grid_maps.Direction.t = function
  | North -> East
  | East -> South
  | South -> West
  | West -> North

let turns facing n =
  let rec go d k =
    if k = 0 then []
    else
      let next = clockwise d in
      next :: go next (k - 1)
  in
  go facing n

let encounter m =
  let facts = Screen_facts.of_measurements m in
  facts.battle || facts.fade <> No_fade

let turn d =
  Wire.press ~hold_ms:turn_hold_ms ~cooldown_ms:turn_release_ms [ M.dpad d ]

let seen_now () =
  match Effects.read () with Some m -> encounter m | None -> false

let rec spin_from ~log facing batch ~max_batches =
  if seen_now () then
    log (Printf.sprintf "Spin: an encounter after %d batches." batch)
  else if batch >= max_batches then
    M.fail "no_encounter" (Printf.sprintf "no wild battle in %d batches" batch)
  else
    let ds = turns facing batch_turns in
    match Effects.race (List.map turn ds) ~stop:encounter with
    | Stopped _ ->
        log (Printf.sprintf "Spin: an encounter in batch %d." (batch + 1))
    | Finished _ ->
        spin_from ~log (List.nth ds (batch_turns - 1)) (batch + 1) ~max_batches

let spin ~log ~facing ~max_batches = spin_from ~log facing 0 ~max_batches
