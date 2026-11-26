open Frlg_readers
module M = Menu_input
module Steps = Frlg_menu_cursor.Cursor_steps

type trip = { from : string; to_ : string; row : int }

let islands =
  [
    ("OneIsland_Harbor", [ "TwoIsland"; "ThreeIsland" ]);
    ("TwoIsland_Harbor", [ "OneIsland"; "ThreeIsland" ]);
  ]

let island_list = Script_menu.seagallop_islands
let where = "ferry: "
let bad e = Error (Pokemon_engine.Failure.cause ~repeats:true "bad_args" e)

let trip_on from to_ =
  match List.assoc_opt from islands with
  | None -> bad (where ^ "no Seagallop list is read at " ^ from)
  | Some list -> (
      match List.find_index (String.equal to_) list with
      | Some row -> Ok { from; to_; row }
      | None -> bad (Printf.sprintf "%s%s's list has no %s" where from to_))

let trip_of_args ~from args =
  match
    (from, Json_field.catch (fun () -> Json_field.string ~where "to" args))
  with
  | _, Error e -> bad e
  | None, _ -> bad (where ^ "no harbor to sail from: the position is unknown")
  | Some from, Ok to_ -> trip_on from to_

(* sSeagallopSpawnLocations: (8, 5) of every Sevii harbor. *)
let landing : Grid_geometry.Tile_pos.t = { x = 8; y = 5 }

let arrival trip : Pokemon_engine.Pose.observed =
  { at_map = trip.to_ ^ "_Harbor"; at_tile = landing; faces = Some South }

(* The text box opening after the A, as a talk's. *)
let talk_ms = 500

(* The sailor's "Where do you want to sail?" prints before the list shows. *)
let list_timeout_ms = 5000

(* Between the A presses on the island while the list does not close. *)
let pick_press_ms = 1000
let max_pick_presses = 3
let list_closed m = Script_menu.cursor_row island_list m = None

let pick trip =
  let read = Script_menu.cursor_row island_list in
  match
    Steps.step_to ~timeout_ms:list_timeout_ms
      ~tap:(fun b -> M.taps b 1)
      read trip.row
  with
  | Reached ->
      M.press_until ~max_presses:max_pick_presses ~code:"seagallop_list_open"
        "the Seagallop list closed" Wire.A ~cooldown_ms:pick_press_ms
        list_closed
  | Unread -> M.fail "no_seagallop_list" "the sailor's list did not show"
  | Stuck at ->
      M.fail "no_seagallop_list"
        (Printf.sprintf "the list's cursor stayed on %d, not %d" at trip.row)

let sail ~log trip =
  log
    (Printf.sprintf "Seagallop: %s to %s (row %d)." trip.from trip.to_ trip.row);
  M.press Wire.A ~cooldown_ms:talk_ms;
  Effects.with_probes (Script_menu.probes island_list) (fun () -> pick trip);
  M.raise_error
    (Scene_readings.settle ~await_fade_in:true Talk ~label:"Seagallop"
       ~battle_ends:false ~log)

let run ~log ~from args =
  Result.bind (trip_of_args ~from args) (fun trip ->
      Result.map (fun () -> arrival trip) (M.run (fun () -> sail ~log trip)))
