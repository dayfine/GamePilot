type item = Shard_s | Shard_l | Other
type goal = Slates of int | Shards of { shard_s : int; shard_l : int }
type tally = { shard_s : int; shard_l : int; digs : int; walls_bailed : int }
type priority = Large_first | Small_only | Large_only

let small_per_slate = 3
let ramanas_total_slates = 14
let ramanas_all_slates = Slates ramanas_total_slates
let empty_tally = { shard_s = 0; shard_l = 0; digs = 0; walls_bailed = 0 }
let slate_equivalents t = t.shard_l + (t.shard_s / small_per_slate)

let is_met goal t =
  match goal with
  | Slates n -> slate_equivalents t >= n
  | Shards req -> t.shard_s >= req.shard_s && t.shard_l >= req.shard_l

let remaining_slates goal t =
  match goal with
  | Slates n -> max 0 (n - slate_equivalents t)
  | Shards req ->
      let rem_l = max 0 (req.shard_l - t.shard_l) in
      let rem_s = max 0 (req.shard_s - t.shard_s) in
      let s_slates = (rem_s + small_per_slate - 1) / small_per_slate in
      rem_l + s_slates

let priority goal t =
  match goal with
  | Slates _ -> Large_first
  | Shards req ->
      let need_s = t.shard_s < req.shard_s in
      let need_l = t.shard_l < req.shard_l in
      if need_l && not need_s then Large_only
      else if need_s && not need_l then Small_only
      else Large_first

let wants_item goal t item =
  match (item, priority goal t) with
  | Other, _ -> false
  | Shard_l, Small_only -> false
  | Shard_s, Large_only -> false
  | Shard_l, (Large_first | Large_only) -> true
  | Shard_s, (Large_first | Small_only) -> true

let record_dig t ~bailed items =
  let add_item (s, l) = function
    | Shard_s -> (s + 1, l)
    | Shard_l -> (s, l + 1)
    | Other -> (s, l)
  in
  let shard_s, shard_l = List.fold_left add_item (t.shard_s, t.shard_l) items in
  let walls_bailed = if bailed then t.walls_bailed + 1 else t.walls_bailed in
  { shard_s; shard_l; digs = t.digs + 1; walls_bailed }
