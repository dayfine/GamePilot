open Checkpoints_plan

let dir ~states ~checkpoint = Filename.concat states (checkpoint ^ ".events")
let file ~index ~event_id = Printf.sprintf "%02d-%s.ss" (index + 1) event_id

let path ~states ~checkpoint ~index ~event_id =
  Filename.concat (dir ~states ~checkpoint) (file ~index ~event_id)

let kept_path state = Filename.remove_extension state ^ ".json"

let is_other_state ~index ~keep name =
  let prefix = Printf.sprintf "%02d-" (index + 1) in
  String.starts_with ~prefix name
  && name <> keep
  && name <> Filename.basename (kept_path keep)
  && (Filename.check_suffix name ".ss" || Filename.check_suffix name ".json")

type kept = { start : Postcondition_check.start; at : Pose.observed option }

let pose_to_json (p : Pose.observed) =
  `Assoc
    [
      ("map", `String p.at_map);
      ("tile", `List [ `Int p.at_tile.x; `Int p.at_tile.y ]);
      ( "facing",
        match p.faces with
        | Some d -> `String (Grid_maps.Direction.name d)
        | None -> `Null );
    ]

let option_json f = function Some v -> f v | None -> `Null
let int_json n = `Int n

let kept_to_json { start; at } =
  `Assoc
    [
      ("start_money", option_json int_json start.start_money);
      ("start_coins", option_json int_json start.start_coins);
      ( "start_items",
        `Assoc (List.map (fun (i, n) -> (i, int_json n)) start.start_items) );
      ("at", option_json pose_to_json at);
    ]

let facing_of = function
  | `String name -> Grid_maps.Direction.of_name name
  | _ -> None

let pose_of_json = function
  | `Null -> Ok None
  | `Assoc f -> (
      match (List.assoc_opt "map" f, List.assoc_opt "tile" f) with
      | Some (`String at_map), Some (`List [ `Int x; `Int y ]) ->
          let faces = Option.bind (List.assoc_opt "facing" f) facing_of in
          Ok (Some { Pose.at_map; at_tile = { x; y }; faces })
      | _ -> Error "at: not a map and a tile")
  | _ -> Error "at: not an object"

let count_of_json name = function
  | `Int n -> Ok (Some n)
  | `Null -> Ok None
  | _ -> Error (name ^ " is not a number")

let field fields name = Option.value (List.assoc_opt name fields) ~default:`Null
let ( let* ) = Result.bind

let rec items_read = function
  | [] -> Ok []
  | (item, `Int n) :: rest ->
      let* rest = items_read rest in
      Ok ((item, n) :: rest)
  | (item, _) :: _ -> Error ("start_items: " ^ item ^ " is not a number")

(* Each item's count at the start; none in a file kept before items were. *)
let items_of_json = function
  | `Null -> Ok []
  | `Assoc items -> items_read items
  | _ -> Error "start_items is not an object"

let kept_of_json = function
  | `Assoc fields ->
      let count name = count_of_json name (field fields name) in
      let* start_money = count "start_money" in
      let* start_coins = count "start_coins" in
      let* start_items = items_of_json (field fields "start_items") in
      let* at = pose_of_json (field fields "at") in
      Ok { start = { start_money; start_coins; start_items }; at }
  | _ -> Error "what is kept is not an object"

let missing ~checkpoint ~label ~path =
  Printf.sprintf
    "no state for %s %s yet (%s): a run of %s on mGBA that reaches %s keeps \
     one, e.g. run/run_checkpoints_on_mgba.sh ... --from %s --to %s --mode \
     testing"
    checkpoint label path checkpoint label checkpoint checkpoint

type tracker = { mutable next : int; mutable clean : bool }

let tracker ~first = { next = first; clean = true }

let hear t index (progress : Event_progress.t) =
  match progress with
  | Started -> t.clean && index = t.next
  | Passed | Skipped _ ->
      if index = t.next then t.next <- index + 1 else t.clean <- false;
      false
  | Failed _ ->
      t.clean <- false;
      false
