(** What a map holds besides its tiles: where it came from, its warps, the
    objects standing on it, the scenes stepping somewhere starts, its edges and
    the tiles measured on the console. Types only; {!Map_data} reads them from a
    map file. *)

type source = { decomp_file : string; revision : string; date : string }
(** Where the tiles came from: the decompilation file, at which revision, read
    when. *)

type world = { world_name : string; offset : Tile_pos.t }
(** Where the map lies on a world grid several maps share (a BDSP map matrix):
    its tile (0, 0) is tile [offset] of world [world_name]. Maps on the same
    world join where they meet. *)

(** How the player takes a warp, as the map file writes it. *)
type warp_entry =
  | Walk_into  (** ["walk_into"]: a door or cave mouth, walked into *)
  | Step_on
      (** ["step_on"]: stepping onto the tile (ladders, escalators, BDSP's warp
          tiles) *)
  | Cave_entrance
      (** ["cave_entrance"]: stepping onto the tile; the game walks a player
          arriving on it a tile south *)
  | Walk of Direction.t
      (** ["walk_north"] ...: standing on the tile and walking that way (exit
          mats, stairs at the side of a room) *)

type warp_destination = { to_map : string; to_point : string }
(** Where a warp puts the player: point [to_point] of map [to_map]. *)

type warp = {
  warp_pos : Tile_pos.t;
  enter : warp_entry;
  destination : warp_destination option;
      (** [None] for a warp to a map that is not in the set: the warp is still
          there, for routes to keep off. *)
  one_way : bool;
      (** A drop (a hole the player falls through): the landing has no way back
          up, so a route takes it forward only. *)
}

type object_kind = Npc | Item | Sign_object

type tile_box = { top_left : Tile_pos.t; bottom_right : Tile_pos.t }
(** A box of tiles, both corners inclusive. *)

type trainer = { sight : int; looks : Direction.t list }
(** A trainer sees [sight] tiles (at least 1) ahead in each direction of [looks]
    (their facing, unless the map says otherwise). *)

type map_object = {
  object_name : string;
  kind : object_kind;
  object_pos : Tile_pos.t;
  facing : Direction.t option;
  wander : tile_box option;
      (** A person who wanders may stand anywhere in it. *)
  trainer : trainer option;
  hide_flag : string option;
      (** The game hides the object while this is set (an event flag, or a story
          state the game's code sets). *)
  script : string option;
      (** The decompilation's script for it ([source_script], e.g.
          ["CeladonCity_GameCorner_EventScript_CoinsClerk"]): how a table that
          refers to it names it. Not unique for shared scripts (Cut trees). *)
}
(** Something standing on a tile, which blocks it. *)

type hidden_item = { hidden_flag : string; hidden_pos : Tile_pos.t }
(** An item hidden on a tile (the decompilation's hidden-item bg event), named
    by the flag the game sets once it is found. It does not block the tile. *)

type trigger = {
  trigger_name : string;
  box : tile_box;
  story_when : string option;
}
(** A scene that starts when the player steps into [box] while the story is at
    [story_when] (any time, if [None]): the decompilation's coord events. *)

type connection = { side : Direction.t; connected_map : string; shift : int }
(** Walking off the map's [side] continues on [connected_map], whose tiles are
    shifted by [shift] along that side. *)

type patch = {
  patch_pos : Tile_pos.t;
  tile : Tile_kind.t;
  measured_by : string;
}
(** A tile measured on the console that differs from the decompilation's. *)
