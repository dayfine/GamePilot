open Grid_maps

let tag = "[Leg] "

module End_kind = struct
  type t = Open | Wall | Tile

  let name = function Open -> "open" | Wall -> "wall" | Tile -> "tile"
end

module End_known = struct
  type t = Wall | Fade | Dialogue | Counted | Dead_reckoned | Seen | Unknown

  let name = function
    | Wall -> "wall"
    | Fade -> "fade"
    | Dialogue -> "dialogue"
    | Counted -> "counted"
    | Dead_reckoned -> "dead_reckoned"
    | Seen -> "seen"
    | Unknown -> "unknown"
end

module Interrupt = struct
  type t = Wild_battle | Trainer | Scene | Dialogue | Blocked

  let name = function
    | Wild_battle -> "wild_battle"
    | Trainer -> "trainer"
    | Scene -> "scene"
    | Dialogue -> "dialogue"
    | Blocked -> "blocked"
end

type plan = {
  direction : Direction.t;
  tiles : int;
  end_kind : End_kind.t;
  ends : Route_tile.t list;
}

let plan direction tiles end_kind = { direction; tiles; end_kind; ends = [] }

type t = {
  checkpoint : string;
  event : string;
  leg : int;
  plan : plan;
  moved : int option;
  chunks : int;
  walked_ms : int;
  end_tiles : Route_tile.t list;
  known : End_known.t;
  interrupts : Interrupt.t list;
  note : string option;
}

(* [["Route 202", 23, 25], ...] *)
let tiles_json tiles =
  `List
    (List.map
       (fun (tile : Route_tile.t) ->
         `List [ `String tile.map; `Int tile.pos.x; `Int tile.pos.y ])
       tiles)

let optional key value = Option.to_list (Option.map (fun v -> (key, v)) value)

let fields record : (string * Yojson.Safe.t) list =
  [
    ("checkpoint", `String record.checkpoint);
    ("event", `String record.event);
    ("leg", `Int record.leg);
    ("dir", `String (Direction.name record.plan.direction));
    ("tiles", `Int record.plan.tiles);
    ("end_kind", `String (End_kind.name record.plan.end_kind));
    ("planned_end", tiles_json record.plan.ends);
    ("chunks", `Int record.chunks);
    ("ms", `Int record.walked_ms);
    ("end", tiles_json record.end_tiles);
    ("known", `String (End_known.name record.known));
    ( "interrupts",
      `List (List.map (fun i -> `String (Interrupt.name i)) record.interrupts)
    );
  ]
  @ optional "moved" (Option.map (fun n -> `Int n) record.moved)
  @ optional "note" (Option.map (fun s -> `String s) record.note)

let to_json record =
  let sorted =
    List.sort (fun (a, _) (b, _) -> String.compare a b) (fields record)
  in
  Yojson.Safe.to_string (`Assoc sorted)

let to_line record = tag ^ to_json record

let end_kind_of_text = function
  | "to wall" -> Some End_kind.Wall
  | "warp" -> Some End_kind.Tile
  | "open" -> Some End_kind.Open
  | _ -> None

(* "<direction> <tiles> (<end>) to <tiles>", the leg line after "Leg n/m: ". *)
let plan_of_leg_text text =
  let open Log_text in
  let ( let* ) = Option.bind in
  let* space = find text " " in
  let* opening = find text " (" in
  let* close = find text ") to " in
  let* () = if space <= opening && opening < close then Some () else None in
  let* direction = Direction.of_name (slice text 0 space) in
  let* tiles = int (slice text (space + 1) opening) in
  let* () = if tiles >= 0 then Some () else None in
  let* end_kind = end_kind_of_text (slice text (opening + 2) close) in
  let after = slice text (close + String.length ") to ") (String.length text) in
  Some { direction; tiles; end_kind; ends = Route_tile.parse_list after }

let plan_of_leg_line line =
  if not (String.starts_with ~prefix:"Leg " line) then None
  else
    Option.bind (Log_text.find line ": ") (fun colon ->
        plan_of_leg_text (Log_text.slice line (colon + 2) (String.length line)))
