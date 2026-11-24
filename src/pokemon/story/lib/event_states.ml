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

type kept = { start_money : int option; at : Pose.observed option }

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

let kept_to_json r =
  `Assoc
    [
      ("start_money", option_json (fun n -> `Int n) r.start_money);
      ("at", option_json pose_to_json r.at);
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

let money_of_json = function
  | Some (`Int n) -> Ok (Some n)
  | Some `Null | None -> Ok None
  | Some _ -> Error "start_money is not a number"

let field fields name = Option.value (List.assoc_opt name fields) ~default:`Null
let ( let* ) = Result.bind

let kept_of_json = function
  | `Assoc fields ->
      let* start_money = money_of_json (List.assoc_opt "start_money" fields) in
      let* at = pose_of_json (field fields "at") in
      Ok { start_money; at }
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
