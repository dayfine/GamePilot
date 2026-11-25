open Json_field

type format = V1 | V2

let v1_name = "pokesim-runtime-map/1"
let v2_name = "pokesim-runtime-map/2"
let object_groups = [ "npcs"; "items"; "signs"; "interactables" ]
let positioned_sections = [ "warps"; "patches"; "coord_events"; "hidden_items" ]

let without keys (obj : obj) =
  List.filter (fun (k, _) -> not (List.mem k keys)) obj

let int32_min = -0x8000_0000
let int32_max = 0x7FFF_FFFF

let coordinate where : Yojson.Safe.t option -> int = function
  | None -> fail "%s is missing." where
  | Some (`Int n) when n >= int32_min && n <= int32_max -> n
  | Some (`Int _) -> fail "%s does not fit a native coordinate." where
  | Some _ -> fail "%s is not an integer." where

(* [keys] are the v1 field names of a position and its v2 pair name. *)
let position format ~where (x_key, y_key, pair_key) obj : Tile_pos.t =
  match (format, find pair_key obj) with
  | V1, Some _ -> fail "%s%s is not a v1 coordinate field." where pair_key
  | V1, None ->
      {
        x = coordinate (where ^ x_key) (find x_key obj);
        y = coordinate (where ^ y_key) (find y_key obj);
      }
  | V2, Some (`List [ x; y ]) when not (has x_key obj || has y_key obj) ->
      let at i = Printf.sprintf "%s%s[%d]" where pair_key i in
      { x = coordinate (at 0) (Some x); y = coordinate (at 1) (Some y) }
  | V2, Some (`List _) when not (has x_key obj || has y_key obj) ->
      fail "%s%s requires exactly two integers." where pair_key
  | V2, _ -> fail "%s%s requires only the v2 coordinate pair." where pair_key

let wander format ~where value : Yojson.Safe.t =
  let obj = as_object where value in
  let low = position format ~where ("x0", "y0", "min") obj in
  let high = position format ~where ("x1", "y1", "max") obj in
  if format = V2 && (low.x > high.x || low.y > high.y) then
    fail "%smust have inclusive min <= max bounds." where;
  `Assoc
    (without [ "x0"; "y0"; "x1"; "y1"; "min"; "max" ] obj
    @ [
        ("x0", `Int low.x);
        ("y0", `Int low.y);
        ("x1", `Int high.x);
        ("y1", `Int high.y);
      ])

let record format ~where value =
  let obj = as_object where value in
  let pos = position format ~where ("x", "y", "coord") obj in
  without [ "x"; "y"; "coord" ] obj @ [ ("x", `Int pos.x); ("y", `Int pos.y) ]

let set key value obj = without [ key ] obj @ [ (key, value) ]

let pickup_name ~where obj =
  match find "source_event" obj with
  | Some event ->
      let index = coordinate (where ^ "source_event") (Some event) in
      if index < 0 then fail "%ssource_event must be nonnegative." where;
      if has "name" obj then obj
      else set "name" (`String (Printf.sprintf "item_%d" index)) obj
  | None when has "name" obj -> obj
  | None -> fail "%sunnamed pickup requires source_event." where

(* A v2 pickup's defaults, without changing an authored name or count. *)
let pickup ~where obj =
  (match find "item" obj with
  | Some (`String item) when item <> "" -> ()
  | _ -> fail "%sitem must be a nonempty string." where);
  let obj = pickup_name ~where obj in
  match find "quantity" obj with
  | None -> set "quantity" (`Int 1) obj
  | Some (`Int n) when n > 0 -> obj
  | Some _ -> fail "%squantity must be a positive integer." where

let kind_of_group = function "npcs" -> "npc" | "signs" -> "sign" | _ -> "item"

let check_group_rules group ~where obj =
  let has_reward = has "item" obj || has "quantity" obj in
  match group with
  | "interactables" -> (
      let action =
        match find "interaction" obj with
        | Some (`Assoc interaction) -> find "kind" interaction
        | _ -> None
      in
      match action with
      | Some (`String kind) when kind <> "" && not has_reward -> ()
      | _ -> fail "%srequires an interaction without an item reward." where)
  | "items" when has "interaction" obj ->
      fail "%sinteractions belong in interactables." where
  | _ -> ()

(* One v2 group's records (or v1's "objects"), in v1 form. *)
let group_records format group ~where items =
  let one i value =
    let where = item_where where group i in
    let obj = record format ~where value in
    let obj =
      match format with
      | V1 -> obj
      | V2 when has "kind" obj ->
          fail "%skind is redundant in v2 typed arrays." where
      | V2 -> obj @ [ ("kind", `String (kind_of_group group)) ]
    in
    check_group_rules group ~where obj;
    let obj =
      if group = "items" && (has "item" obj || has "quantity" obj) then
        pickup ~where obj
      else obj
    in
    match find "wander" obj with
    | Some box ->
        set "wander" (wander format ~where:(where ^ "wander.") box) obj
    | None -> obj
  in
  List.mapi (fun i value -> `Assoc (one i value)) items

let array where : Yojson.Safe.t -> Yojson.Safe.t list = function
  | `List items -> items
  | _ -> fail "%s must be an array." where

let v1_objects ~where root =
  List.iter
    (fun group ->
      if has group root then fail "%s%s is not a v1 object section." where group)
    object_groups;
  Option.map
    (fun value ->
      group_records V1 "objects" ~where (array (where ^ "objects") value))
    (find "objects" root)

let v2_objects ~where root =
  if has "objects" root then
    fail "%sobjects cannot be combined with v2 typed arrays." where;
  let present = List.filter (fun group -> has group root) object_groups in
  let group_of name =
    group_records V2 name ~where (array (where ^ name) (List.assoc name root))
  in
  if present = [] then None else Some (List.concat_map group_of present)

let read_format ~where root =
  match find "format" root with
  | None -> V1
  | Some (`String name) when name = v1_name -> V1
  | Some (`String name) when name = v2_name -> V2
  | Some _ -> fail "%sformat is unsupported." where

let section_records format ~where name value : Yojson.Safe.t =
  let one i item =
    `Assoc (record format ~where:(item_where where name i) item)
  in
  `List (List.mapi one (array (where ^ name) value))

let section format ~where root name =
  Option.map
    (fun value -> (name, section_records format ~where name value))
    (find name root)

let to_v1 ~where json =
  let root = as_object where json in
  let format = read_format ~where root in
  let objects =
    match format with
    | V1 -> v1_objects ~where root
    | V2 -> v2_objects ~where root
  in
  let kept =
    without
      (("format" :: "objects" :: object_groups) @ positioned_sections)
      root
  in
  let objects =
    Option.to_list (Option.map (fun list -> ("objects", `List list)) objects)
  in
  `Assoc
    (kept @ objects
    @ List.filter_map (section format ~where root) positioned_sections)
