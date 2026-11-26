module T = Switch_home.Timed_press
module B = Box_view

let ( let* ) = Result.bind

type t = { name : string; game_col : int; boxes : int list; order : B.order }

let home_first : B.slot = { pane = Home_box; row = 0; col = 0 }
let game_slot move : B.slot = { pane = Game_box; row = 0; col = move.game_col }

let cursor_probes moves =
  List.concat_map B.cursor_probes (home_first :: List.map game_slot moves)

let read_ms = 1500

let holds ~what check =
  match Effects.await ~timeout_ms:read_ms check with
  | Holds _ -> Ok ()
  | Timeout -> Error what

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
      Error ("could not read HOME's box number: " ^ counter)

let goto_box target =
  let rec go n =
    let* current = read_number () in
    let d = target - current in
    if d = 0 then Ok ()
    else if n >= box_rounds then
      Error (Printf.sprintf "HOME box %d not reached (on %d)" target current)
    else (
      T.press_all (T.times (min (abs d) max_switches) (switch_button d));
      Switch_home.Switch_presses.wait settle_ms;
      go (n + 1))
  in
  go 0

let empty_in move box =
  Result.map
    (fun () ->
      Option.bind (Effects.read ()) (fun m -> B.first_empty m move.order))
    (goto_box box)

let all_full move =
  Printf.sprintf "HOME boxes %s are full: %s not moved"
    (String.concat ", " (List.map string_of_int move.boxes))
    move.name

let rec find_slot ~log move = function
  | [] -> Error (all_full move)
  | box :: rest -> (
      match empty_in move box with
      | Error e -> Error e
      | Ok (Some slot) -> Ok (box, slot)
      | Ok None ->
          log (Printf.sprintf "HOME box %d is full." box);
          find_slot ~log move rest)

let dpad button : T.t = { button; hold_ms = 80; cooldown_ms = 200 }
let steps n button = T.times n (dpad button)
let pick : T.t = { button = Y; hold_ms = 100; cooldown_ms = 350 }
let drop : T.t = { button = Y; hold_ms = 100; cooldown_ms = 400 }

let cursor_on slot =
  holds
    ~what:("the cursor is not on " ^ B.slot_to_string slot)
    (fun m -> B.cursor_at m slot)

let unsaved = "; Pokémon HOME left open, unsaved"

let drop_on ~log move (box, (slot : B.slot)) =
  let source = game_slot move in
  let across = B.columns + move.game_col - slot.col in
  T.press_all (steps slot.row Down @ steps across Left @ [ drop ]);
  let* () =
    holds
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
  let source = game_slot move in
  let* () = cursor_on home_first in
  let* () =
    holds
      ~what:
        (Printf.sprintf "no Pokémon in %s for %s" (B.slot_to_string source)
           move.name)
      (fun m -> B.occupied m source)
  in
  let* target = find_slot ~log move move.boxes in
  T.press_all (steps (B.columns + move.game_col) Right);
  let* () = cursor_on source in
  T.press pick;
  drop_on ~log move target
