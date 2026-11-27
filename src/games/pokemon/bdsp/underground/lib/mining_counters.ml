type treasure =
  | Shard_s
  | Shard_l
  | Sphere
  | Evolution_stone
  | Fossil
  | Statue_box
  | Other_treasure

type t = {
  cycles : int;
  refreshes : int;
  skipped_corridors : int;
  digs : int;
  walls_bailed : int;
  battles_escaped : int;
  shard_s : int;
  shard_l : int;
  spheres : int;
  stones : int;
  fossils : int;
  statue_boxes : int;
  other_treasures : int;
}

let empty =
  {
    cycles = 0;
    refreshes = 0;
    skipped_corridors = 0;
    digs = 0;
    walls_bailed = 0;
    battles_escaped = 0;
    shard_s = 0;
    shard_l = 0;
    spheres = 0;
    stones = 0;
    fossils = 0;
    statue_boxes = 0;
    other_treasures = 0;
  }

let record_cycle c = { c with cycles = c.cycles + 1 }
let record_refresh c = { c with refreshes = c.refreshes + 1 }

let record_skipped_corridor c =
  { c with skipped_corridors = c.skipped_corridors + 1 }

let record_battle_escaped c = { c with battles_escaped = c.battles_escaped + 1 }

let add_treasure c = function
  | Shard_s -> { c with shard_s = c.shard_s + 1 }
  | Shard_l -> { c with shard_l = c.shard_l + 1 }
  | Sphere -> { c with spheres = c.spheres + 1 }
  | Evolution_stone -> { c with stones = c.stones + 1 }
  | Fossil -> { c with fossils = c.fossils + 1 }
  | Statue_box -> { c with statue_boxes = c.statue_boxes + 1 }
  | Other_treasure -> { c with other_treasures = c.other_treasures + 1 }

let record_dig c ~bailed items =
  let c = List.fold_left add_treasure c items in
  let walls_bailed = if bailed then c.walls_bailed + 1 else c.walls_bailed in
  { c with digs = c.digs + 1; walls_bailed }

let to_tally c : Mining_goal.tally =
  {
    shard_s = c.shard_s;
    shard_l = c.shard_l;
    digs = c.digs;
    walls_bailed = c.walls_bailed;
  }

let target_slates = function
  | Mining_goal.Slates n -> n
  | Mining_goal.Shards req ->
      req.shard_l
      + (req.shard_s + Mining_goal.small_per_slate - 1)
        / Mining_goal.small_per_slate

let format_summary ~goal c =
  let slates = Mining_goal.slate_equivalents (to_tally c) in
  let target = target_slates goal in
  Printf.sprintf
    "cycles=%d refreshes=%d skipped=%d digs=%d bailed=%d battles=%d | shards \
     S=%d L=%d (slates=%d/%d) | spheres=%d stones=%d fossils=%d boxes=%d \
     other=%d"
    c.cycles c.refreshes c.skipped_corridors c.digs c.walls_bailed
    c.battles_escaped c.shard_s c.shard_l slates target c.spheres c.stones
    c.fossils c.statue_boxes c.other_treasures

let watch_items ~goal ~total_cycles c =
  let slates = Mining_goal.slate_equivalents (to_tally c) in
  let target = target_slates goal in
  let digs_val =
    if c.walls_bailed > 0 then
      Printf.sprintf "%d (%d bailed)" c.digs c.walls_bailed
    else string_of_int c.digs
  in
  let refresh_val =
    if c.skipped_corridors > 0 then
      Printf.sprintf "%d (%d skipped)" c.refreshes c.skipped_corridors
    else string_of_int c.refreshes
  in
  [
    ("Cycles", Printf.sprintf "%d / %d" c.cycles total_cycles);
    ("Refreshes", refresh_val);
    ("Digs", digs_val);
    ("Shards (S / L)", Printf.sprintf "%d / %d" c.shard_s c.shard_l);
    ("Slates", Printf.sprintf "%d / %d" slates target);
    ("Spheres", string_of_int c.spheres);
    ("Stones / Fossils", Printf.sprintf "%d / %d" c.stones c.fossils);
    ("Boxes / Other", Printf.sprintf "%d / %d" c.statue_boxes c.other_treasures);
    ("Battles", string_of_int c.battles_escaped);
  ]
