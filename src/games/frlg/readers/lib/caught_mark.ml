let mark_id = "battle.foe.caught"
let above_id = "battle.foe.caught_above"
let left_id = "battle.foe.caught_left"

(* The ball's 7 by 7 outline in the HP box, and the HP box's cream in the two
   rows above it and the three columns left of it (mGBA, dex-route10/). *)
let mark_box = Game_pixels.box { x = 20.; y = 31.; w = 7.; h = 7. }
let above_box = Game_pixels.box { x = 16.; y = 29.; w = 14.; h = 2. }
let left_box = Game_pixels.box { x = 17.; y = 31.; w = 3.; h = 7. }
let dark_max = 115
let min_share = 0.15
let max_share = 0.6
let min_cream_channel = 170.
let max_cream_stddev_sum = 45.

let dark : Color_count.range =
  {
    low = { r = 0; g = 0; b = 0 };
    high = { r = dark_max; g = dark_max; b = dark_max };
  }

let probes =
  [
    Color_count.probe ~id:mark_id mark_box dark;
    Solid_color.probe ~id:above_id above_box;
    Solid_color.probe ~id:left_id left_box;
  ]

let cream (s : Solid_color.stats) =
  Float.min s.mean.r (Float.min s.mean.g s.mean.b) >= min_cream_channel
  && Solid_color.sum s.stddev <= max_cream_stddev_sum

let caught m =
  Solid_color.holds m above_id cream
  && Solid_color.holds m left_id cream
  &&
  match Color_count.share m mark_id with
  | Some share -> share >= min_share && share <= max_share
  | None -> false

let read m =
  match Color_count.share m mark_id with
  | None -> None
  | Some _ -> Some (caught m)
