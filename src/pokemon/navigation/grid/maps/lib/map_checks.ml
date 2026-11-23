open Json_field
open Map_features
open Map_gates

let inside (map : Map_data.t) what pos =
  if not (Grid.contains map.tiles pos) then
    fail "%s %s is outside the %dx%d map." what (Tile_pos.to_string pos)
      (Grid.width map.tiles) (Grid.height map.tiles)

let box_inside map what box =
  inside map what box.top_left;
  inside map what box.bottom_right

let each where key items check =
  List.iteri
    (fun i item -> check (Printf.sprintf "%s%s[%d]" where key i) item)
    items

let places_inside ~where (map : Map_data.t) =
  Map_data.String_map.iter
    (fun name pos -> inside map (Printf.sprintf "%spoints.%s" where name) pos)
    map.points;
  Map_data.String_map.iter
    (fun name tiles -> each where ("regions." ^ name) tiles (inside map))
    map.regions;
  each where "warps" map.warps (fun what warp -> inside map what warp.warp_pos);
  each where "objects" map.objects (fun what obj ->
      inside map what obj.object_pos;
      Option.iter (box_inside map (what ^ ".wander")) obj.wander);
  each where "triggers" map.triggers (fun what trigger ->
      box_inside map (what ^ ".box") trigger.box);
  each where "patches" map.patches (fun what patch ->
      inside map what patch.patch_pos)

let tile_is (map : Map_data.t) what pos kind name =
  inside map what pos;
  if Grid.get map.tiles pos <> kind then
    fail "%s %s is not a %s tile." what (Tile_pos.to_string pos) name

(* Each gate tile is a G tile and in this gate only; returns the tiles seen. *)
let gate_tiles ~where map seen (gate : gate) =
  let what i = Printf.sprintf "%sgates.%s.tiles[%d]" where gate.gate_id i in
  let claim (i, seen) pos =
    tile_is map (what i) pos Tile_kind.Gate "G";
    if List.exists (Tile_pos.equal pos) seen then
      fail "%s %s is in another gate too." (what i) (Tile_pos.to_string pos);
    (i + 1, pos :: seen)
  in
  snd (List.fold_left claim (0, seen) gate.gate_tiles)

let gate_switch_listed ~where (map : Map_data.t) (gate : gate) =
  match gate.control with
  | Switch { switch_id; _ }
    when not (Map_data.String_map.mem switch_id map.switches) ->
      fail "%sgates.%s.switch \"%s\" is not in switches." where gate.gate_id
        switch_id
  | _ -> ()

let every_gate_tile_listed ~where (map : Map_data.t) claimed =
  List.iter
    (fun pos ->
      if
        Grid.get map.tiles pos = Tile_kind.Gate
        && not (List.exists (Tile_pos.equal pos) claimed)
      then
        fail "%stiles has a G at %s that no gate lists." where
          (Tile_pos.to_string pos))
    (Grid.positions map.tiles)

let statue_fits map what statue =
  inside map what statue.statue_tile;
  inside map what statue.face_from;
  if
    not
      (Tile_pos.equal
         (Tile_pos.next statue.face_from statue.facing)
         statue.statue_tile)
  then
    fail "%s: %s does not face %s %s." what
      (Tile_pos.to_string statue.face_from)
      (Tile_pos.to_string statue.statue_tile)
      (Direction.name statue.facing)

let switch_fits ~where (map : Map_data.t) (switch : switch) =
  let where = Printf.sprintf "%sswitches.%s." where switch.switch_name in
  if not (List.mem map.name switch.floors) then
    fail "%sfloors does not name this map, %s." where map.name;
  match switch.press with
  | Statues statues -> each where "statues" statues (statue_fits map)
  | Boulder_buttons { buttons; _ } ->
      each where "buttons" buttons (fun what pos ->
          tile_is map what pos Tile_kind.Strength_button "Strength button (B)")

let holes_one_way ~where (map : Map_data.t) =
  each where "warps" map.warps (fun what warp ->
      if
        Grid.get map.tiles warp.warp_pos = Tile_kind.Fall_hole
        && not warp.one_way
      then
        fail "%s %s is on a hole (H) but not one_way." what
          (Tile_pos.to_string warp.warp_pos))

let gates_fit ~where (map : Map_data.t) =
  let gates = List.map snd (Map_data.String_map.bindings map.gates) in
  let claimed = List.fold_left (gate_tiles ~where map) [] gates in
  List.iter (gate_switch_listed ~where map) gates;
  every_gate_tile_listed ~where map claimed;
  Map_data.String_map.iter
    (fun _ switch -> switch_fits ~where map switch)
    map.switches;
  holes_one_way ~where map
