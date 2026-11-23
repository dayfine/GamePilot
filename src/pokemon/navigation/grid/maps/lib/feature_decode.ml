open Json_field
open Map_features

let source ~where obj =
  let where_source = where ^ "source" in
  let fields = as_object where_source (field ~where "source" obj) in
  let read key = string ~where:(where_source ^ ".") key fields in
  {
    decomp_file = read "decomp_file";
    revision = read "revision";
    date = read "date";
  }

let world ~where obj =
  Option.map
    (fun fields ->
      let where = where ^ "world." in
      { world_name = string ~where "name" fields; offset = pos ~where fields })
    (object_opt ~where "world" obj)

let points ~where obj =
  List.map
    (fun (name, value) ->
      (name, pair (Printf.sprintf "%spoints.%s" where name) value))
    (entries ~where "points" obj)

let region where : Yojson.Safe.t -> Tile_pos.t list = function
  | `List (_ :: _ as tiles) ->
      List.mapi
        (fun i tile -> pair (Printf.sprintf "%s[%d]" where i) tile)
        tiles
  | _ -> fail "%s is not a non-empty list of [x, y]." where

let regions ~where obj =
  List.map
    (fun (name, value) ->
      (name, region (Printf.sprintf "%sregions.%s" where name) value))
    (entries ~where "regions" obj)

let flag_sets ~where obj =
  List.map
    (fun (name, value) ->
      (name, strings (Printf.sprintf "%sflag_sets.%s" where name) value))
    (entries ~where "flag_sets" obj)

let warp_entries =
  [
    ("walk_into", Walk_into);
    ("step_on", Step_on);
    ("cave_entrance", Cave_entrance);
  ]
  @ List.map (fun d -> ("walk_" ^ Direction.name d, Walk d)) Direction.all

let named_entry ~where name =
  match List.assoc_opt name warp_entries with
  | Some entry -> entry
  | None ->
      fail
        "%senter \"%s\" is not walk_into, step_on, cave_entrance or \
         walk_<direction>."
        where name

let warp_entry ~where obj =
  Option.fold ~none:Walk_into ~some:(named_entry ~where)
    (string_opt ~where "enter" obj)

let destination ~where obj =
  match (has "to_map" obj, has "to_point" obj) with
  | false, false -> None
  | true, true ->
      Some
        {
          to_map = string ~where "to_map" obj;
          to_point = string ~where "to_point" obj;
        }
  | true, false -> fail "%sto_point is missing." where
  | false, true -> fail "%sto_map is missing." where

let warp ~where obj =
  {
    warp_pos = pos ~where obj;
    enter = warp_entry ~where obj;
    destination = destination ~where obj;
    one_way = bool_or ~where ~default:false "one_way" obj;
  }

let warps ~where obj = records ~where "warps" obj warp

let object_kind ~where obj =
  match string ~where "kind" obj with
  | "npc" -> Npc
  | "item" -> Item
  | "sign" -> Sign_object
  | kind -> fail "%skind \"%s\" is not npc, item or sign." where kind

let box ~where obj =
  let corner x_key y_key =
    { Tile_pos.x = int ~where x_key obj; y = int ~where y_key obj }
  in
  let top_left = corner "x0" "y0" and bottom_right = corner "x1" "y1" in
  if top_left.x > bottom_right.x || top_left.y > bottom_right.y then
    fail "%s is not a box (x0 <= x1, y0 <= y1)."
      (String.sub where 0 (String.length where - 1));
  { top_left; bottom_right }

let look ~where i : Yojson.Safe.t -> Direction.t =
  let at = Printf.sprintf "%slooks[%d]" where i in
  function
  | `String name -> direction_named at name
  | _ -> fail "%s is not a string." at

let looks ~where ~facing obj =
  match (list_opt ~where "looks" obj, facing) with
  | Some names, _ -> List.mapi (look ~where) names
  | None, Some facing -> [ facing ]
  | None, None -> fail "%slooks is missing, and the object has no facing." where

let trainer ~where ~facing obj =
  let sight = int ~where "sight" obj in
  if sight < 1 then fail "%ssight %d is not at least 1." where sight;
  { sight; looks = looks ~where ~facing obj }

let map_object ~where obj =
  let facing =
    if has "facing" obj then Some (direction ~where "facing" obj) else None
  in
  let sub key read =
    Option.map (read ~where:(where ^ key ^ ".")) (object_opt ~where key obj)
  in
  {
    object_name = string ~where "name" obj;
    kind = object_kind ~where obj;
    object_pos = pos ~where obj;
    facing;
    wander = sub "wander" box;
    trainer = sub "trainer" (trainer ~facing);
    hide_flag = string_opt ~where "hide_flag" obj;
  }

let objects ~where obj = records ~where "objects" obj map_object

let trigger ~where obj =
  let box_where = where ^ "box" in
  {
    trigger_name = string ~where "name" obj;
    box =
      box ~where:(box_where ^ ".")
        (as_object box_where (field ~where "box" obj));
    story_when = string_opt ~where "when" obj;
  }

let triggers ~where obj = records ~where "triggers" obj trigger

let connection ~where obj =
  {
    side = direction ~where "side" obj;
    connected_map = string ~where "to_map" obj;
    shift = int ~where "offset" obj;
  }

let connections ~where obj = records ~where "connections" obj connection

let patch ~where obj =
  let glyph = string ~where "glyph" obj in
  let tile =
    match glyph with
    | _ when String.length glyph <> 1 -> None
    | _ -> Tile_kind.of_glyph glyph.[0]
  in
  match tile with
  | Some tile ->
      {
        patch_pos = pos ~where obj;
        tile;
        measured_by = string ~where "measured_by" obj;
      }
  | None -> fail "%sglyph \"%s\" is not a tile glyph." where glyph

let patches ~where obj = records ~where "patches" obj patch
