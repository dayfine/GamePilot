open Json_field

let string_map pairs =
  List.fold_left
    (fun map (k, v) -> Map_data.String_map.add k v map)
    Map_data.String_map.empty pairs

let keyed key items = string_map (List.map (fun item -> (key item, item)) items)

let with_patches tiles patches =
  List.fold_left
    (fun tiles (patch : Map_features.patch) ->
      Grid.set tiles patch.patch_pos patch.tile)
    tiles patches

let read ~where root : Map_data.t =
  let tiles = Grid_decode.tiles ~where root in
  let patches = Feature_decode.patches ~where root in
  let width = Grid.width tiles and height = Grid.height tiles in
  {
    name = string ~where "name" root;
    source = Feature_decode.source ~where root;
    world = Feature_decode.world ~where root;
    allow_running = bool_or ~where ~default:true "allow_running" root;
    tiles;
    elevation = Grid_decode.elevation ~where ~width ~height root;
    points = string_map (Feature_decode.points ~where root);
    regions = string_map (Feature_decode.regions ~where root);
    warps = Feature_decode.warps ~where root;
    objects = Feature_decode.objects ~where root;
    triggers = Feature_decode.triggers ~where root;
    flag_sets =
      string_map
        (List.map
           (fun (name, flags) -> (name, Map_data.String_set.of_list flags))
           (Feature_decode.flag_sets ~where root));
    connections = Feature_decode.connections ~where root;
    patches;
    gates =
      keyed
        (fun (gate : Map_gates.gate) -> gate.gate_id)
        (Gate_decode.gates ~where root);
    switches =
      keyed
        (fun (switch : Map_gates.switch) -> switch.switch_name)
        (Gate_decode.switches ~where root);
  }

let parse ~source_name json =
  let where = source_name ^ ": " in
  match
    let root = as_object source_name (Runtime_format.to_v1 ~where json) in
    let map = read ~where root in
    Map_checks.places_inside ~where map;
    let map = { map with tiles = with_patches map.tiles map.patches } in
    Map_checks.gates_fit ~where map;
    map
  with
  | map -> Ok map
  | exception Invalid message -> Error message

let of_string ~source_name text =
  match Yojson.Safe.from_string text with
  | json -> parse ~source_name json
  | exception Yojson.Json_error message -> Error (source_name ^ ": " ^ message)

let load path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> of_string ~source_name:path text
  | exception Sys_error message -> Error message

let runtime_dir maps_dir = Filename.concat maps_dir "runtime"
let json_suffix = ".json"

let runtime_path ~maps_dir name =
  Filename.concat (runtime_dir maps_dir) (name ^ json_suffix)

let runtime_names ~maps_dir =
  Sys.readdir (runtime_dir maps_dir)
  |> Array.to_list
  |> List.filter_map (fun file ->
         if Filename.check_suffix file json_suffix then
           Some (Filename.chop_suffix file json_suffix)
         else None)
  |> List.sort String.compare

let load_runtime ~maps_dir name = load (runtime_path ~maps_dir name)
