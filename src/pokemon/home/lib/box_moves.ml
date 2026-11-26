module T = Switch_home.Timed_press
module B = Box_view

let ( let* ) = Result.bind

type source = { box : int; row : int; col : int }
type destination = { boxes : int list; fallback : int list; order : B.order }
type t = { name : string; source : source; destination : destination }
type move_error = { message : string; holding : bool }

let fail ?(holding = false) message = Error { message; holding }
let home_first : B.slot = { pane = Home_box; row = 0; col = 0 }

let game_slot move : B.slot =
  { pane = Game_box; row = move.source.row; col = move.source.col }

let cursor_probes moves =
  List.concat_map B.cursor_probes (home_first :: List.map game_slot moves)

let read_ms = 1500

let holds ?(holding = false) ~what check =
  match Effects.await ~timeout_ms:read_ms check with
  | Holds _ -> Ok ()
  | Timeout -> fail ~holding what

(* goto_home_box. *)
let switch_button d : T.t =
  { button = (if d > 0 then R else L); hold_ms = 100; cooldown_ms = 350 }

let max_switches = 10
let settle_ms = 500
let box_rounds = 25

let read_number () =
  match Effects.await ~timeout_ms:read_ms (fun m -> B.number m <> None) with
  | Holds m -> Ok (Option.value ~default:0 (B.number m))
  | Timeout ->
      let counter =
        Option.fold ~none:"no frame" ~some:B.counter_to_string (Effects.read ())
      in
      fail ("could not read HOME's box number: " ^ counter)

let goto_box target =
  let rec go n =
    let* current = read_number () in
    let d = target - current in
    if d = 0 then Ok ()
    else if n >= box_rounds then
      fail (Printf.sprintf "HOME box %d not reached (on %d)" target current)
    else (
      T.press_all (T.times (min (abs d) max_switches) (switch_button d));
      Switch_home.Switch_presses.wait settle_ms;
      go (n + 1))
  in
  go 0

let empty_in order box =
  Result.map
    (fun () -> Option.bind (Effects.read ()) (fun m -> B.first_empty m order))
    (goto_box box)

let box_list_text boxes = String.concat ", " (List.map string_of_int boxes)

let all_full move =
  let d = move.destination in
  match d.fallback with
  | [] ->
      Printf.sprintf "HOME boxes %s are full: %s not moved"
        (box_list_text d.boxes) move.name
  | fb ->
      Printf.sprintf "HOME boxes %s (fallback %s) are full: %s not moved"
        (box_list_text d.boxes) (box_list_text fb) move.name

let rec try_boxes ~log order = function
  | [] -> Ok None
  | box :: rest -> (
      match empty_in order box with
      | Error e -> Error e
      | Ok (Some slot) -> Ok (Some (box, slot))
      | Ok None ->
          log (Printf.sprintf "HOME box %d is full." box);
          try_boxes ~log order rest)

let try_fallback ~log move =
  match move.destination.fallback with
  | [] -> fail (all_full move)
  | fb -> (
      log
        (Printf.sprintf "Primary HOME boxes full for %s; trying fallback."
           move.name);
      let* found = try_boxes ~log move.destination.order fb in
      match found with Some slot -> Ok slot | None -> fail (all_full move))

let find_slot ~log move =
  let* primary = try_boxes ~log move.destination.order move.destination.boxes in
  match primary with Some found -> Ok found | None -> try_fallback ~log move

let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 200 }
let steps n button = T.times n (dpad button)

let vertical_steps delta =
  if delta > 0 then steps delta Down
  else if delta < 0 then steps (-delta) Up
  else []

let pick : T.t = { button = Y; hold_ms = 100; cooldown_ms = 350 }
let drop : T.t = { button = Y; hold_ms = 100; cooldown_ms = 400 }

let cursor_on slot =
  holds
    ~what:("the cursor is not on " ^ B.slot_to_string slot)
    (fun m -> B.cursor_at m slot)

let unsaved = "; Pokémon HOME left open, unsaved"

let check_source move =
  let s = move.source in
  if s.box <> 1 then
    fail
      (Printf.sprintf "%s: game box %d is not supported (box 1 only)" move.name
         s.box)
  else if s.row < 0 || s.row >= B.slot_rows || s.col < 0 || s.col >= B.columns
  then
    fail
      (Printf.sprintf "%s: invalid game slot (row %d, col %d)" move.name s.row
         s.col)
  else Ok ()

let drop_on ~log move (box, (slot : B.slot)) =
  let source = game_slot move in
  let across = B.columns + move.source.col - slot.col in
  let dy = slot.row - move.source.row in
  T.press_all (vertical_steps dy @ steps across Left @ [ drop ]);
  let* () =
    holds ~holding:true
      ~what:
        (Printf.sprintf "%s did not land in HOME box %d, %s%s" move.name box
           (B.place_to_string slot) unsaved)
      (fun m -> B.occupied m slot && B.empty m source)
  in
  log
    (Printf.sprintf "%s moved to HOME box %d, %s." move.name box
       (B.place_to_string slot));
  T.press_all (steps slot.row Up @ steps slot.col Left);
  cursor_on home_first

let run ~log move =
  let* () = check_source move in
  let source = game_slot move in
  let* () = cursor_on home_first in
  let* () =
    holds
      ~what:
        (Printf.sprintf "no Pokémon in %s for %s" (B.slot_to_string source)
           move.name)
      (fun m -> B.occupied m source)
  in
  let* target = find_slot ~log move in
  T.press_all
    (steps move.source.row Down @ steps (B.columns + move.source.col) Right);
  let* () = cursor_on source in
  T.press pick;
  drop_on ~log move target
