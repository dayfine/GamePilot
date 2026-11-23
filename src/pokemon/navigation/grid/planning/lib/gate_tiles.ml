open Map_gates

let switch_key pressed =
  match pressed.floors with
  | [ floor ] -> Gate_state.gate_key ~map:floor ~gate:pressed.switch_name
  | _ -> pressed.switch_name

let find_value pred map =
  Map_data.String_map.to_seq map |> Seq.map snd |> Seq.find pred

let switch_with_button (map : Map_data.t) pos =
  let has_button pressed =
    match pressed.press with
    | Boulder_buttons { buttons; _ } -> List.exists (Tile_pos.equal pos) buttons
    | Statues _ -> false
  in
  find_value has_button map.switches

let gate_at (map : Map_data.t) pos =
  find_value
    (fun gate -> List.exists (Tile_pos.equal pos) gate.gate_tiles)
    map.gates

let switch_is_on (map : Map_data.t) state switch_id =
  let key =
    match Map_data.String_map.find_opt switch_id map.switches with
    | Some found -> switch_key found
    | None -> switch_id
  in
  Gate_state.switch_on state key

let gate_is_open (map : Map_data.t) (state : Gate_state.t) gate =
  match gate.control with
  | Switch { switch_id; open_when_on } ->
      switch_is_on map state switch_id = open_when_on
  | Flag _ ->
      let key = Gate_state.gate_key ~map:map.name ~gate:gate.gate_id in
      gate.open_at_new_game || Gate_state.Names.mem key state.opened

let resolved_tile (map : Map_data.t) state pos =
  match Grid.get map.tiles pos with
  | Tile_kind.Gate -> (
      match gate_at map pos with
      | Some gate when gate_is_open map state gate -> gate.open_tile
      | _ -> Tile_kind.Wall)
  | tile -> tile

let resolve_tiles (map : Map_data.t) state =
  Grid.init ~width:(Grid.width map.tiles) ~height:(Grid.height map.tiles)
    (resolved_tile map state)

let closed_card_key_gate_faced (map : Map_data.t) state from direction =
  let ahead = Tile_pos.next from direction in
  let closed_card_key gate =
    match gate.control with
    | Flag { opener = Card_key; _ } -> not (gate_is_open map state gate)
    | Flag _ | Switch _ -> false
  in
  match Grid.find map.tiles ahead with
  | Some Tile_kind.Gate ->
      Option.bind (gate_at map ahead) (fun gate ->
          if closed_card_key gate then Some gate else None)
  | _ -> None

let switch_pressed (map : Map_data.t) from direction =
  let faced_from statue =
    Tile_pos.equal statue.face_from from && statue.facing = direction
  in
  let pressed_here switch =
    match switch.press with
    | Statues statues -> List.exists faced_from statues
    | Boulder_buttons _ -> false
  in
  find_value pressed_here map.switches
