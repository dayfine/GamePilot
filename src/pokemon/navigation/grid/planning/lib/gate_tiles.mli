(** What a gate state ({!Gate_state}) makes of a map's tiles: a closed gate is a
    wall; an open one is the tile its [open_tile] names. And which gate or
    switch the player faces or stands on. *)

val switch_key : Map_gates.switch -> string
(** The name {!Gate_state.t.switches_on} knows a switch by: its id when several
    maps share it (Pokemon Mansion's floors), and
    [Gate_state.gate_key ~map ~gate:id] when it is one map's own (each Victory
    Road floor has a ["floor_switch_1"] of its own, with its own flag). *)

val switch_with_button : Map_data.t -> Tile_pos.t -> Map_gates.switch option
(** The switch whose boulder button is on the tile, if any. *)

val gate_at : Map_data.t -> Tile_pos.t -> Map_gates.gate option
(** The gate that has the tile, if any. *)

val gate_is_open : Map_data.t -> Gate_state.t -> Map_gates.gate -> bool
(** A flag gate is open if it is open at a new game or the state has opened it;
    a switch's gate is open while the switch is in its open state. A switch the
    map does not list is known by its id. *)

val resolved_tile : Map_data.t -> Gate_state.t -> Tile_pos.t -> Tile_kind.t
(** The tile for walking: a gate tile is a wall while its gate is closed and its
    gate's [open_tile] once open; any other tile is as it is. Raises
    [Invalid_argument] for a tile off the map. *)

val resolve_tiles : Map_data.t -> Gate_state.t -> Tile_kind.t Grid.t
(** All the map's tiles, resolved. *)

val closed_card_key_gate_faced :
  Map_data.t ->
  Gate_state.t ->
  Tile_pos.t ->
  Direction.t ->
  Map_gates.gate option
(** The closed Card Key gate that a player standing on the tile and facing that
    way faces, if any (not a wall, an open gate, or a gate opened any other
    way). *)

val switch_pressed :
  Map_data.t -> Tile_pos.t -> Direction.t -> Map_gates.switch option
(** The switch with a statue that a player standing on the tile and facing that
    way presses with A, if any. *)
