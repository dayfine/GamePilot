module Cc = Color_count

let badge_names =
  [
    "boulder";
    "cascade";
    "thunder";
    "rainbow";
    "soul";
    "marsh";
    "volcano";
    "earth";
  ]

let slots = List.length badge_names
let star_slots = 4
let body_id = "card.body"
let strip_id = "card.strip"
let badge_id i = Printf.sprintf "card.badge%d" (i + 1)
let star_id k = Printf.sprintf "card.star%d" (k + 1)
let body = Game_pixels.box { x = 24.; y = 56.; w = 88.; h = 8. }
let strip = Game_pixels.box { x = 12.; y = 130.; w = 16.; h = 12. }

(* A badge slot's middle: the slot's 16 by 16 less 2 pixels each side. *)
type slot_geom = {
  first_badge_x : float;
  badge_pitch : float;
  badge_y : float;
  badge_side : float;
  first_star_x : float;
  star_y : float;
  star_side : float;
}

let geom =
  {
    first_badge_x = 34.;
    badge_pitch = 24.;
    badge_y = 130.;
    badge_side = 12.;
    first_star_x = 120.;
    star_y = 56.;
    star_side = 8.;
  }

let badge_box i =
  Game_pixels.box
    {
      x = geom.first_badge_x +. (geom.badge_pitch *. float i);
      y = geom.badge_y;
      w = geom.badge_side;
      h = geom.badge_side;
    }

let star_box k =
  Game_pixels.box
    {
      x = geom.first_star_x +. (geom.star_side *. float k);
      y = geom.star_y;
      w = geom.star_side;
      h = geom.star_side;
    }

let dark_max = 100

let dark : Cc.range =
  {
    low = { r = 0; g = 0; b = 0 };
    high = { r = dark_max; g = dark_max; b = dark_max };
  }

(* The star's yellow: pret's star.pal (255, 213, 82) and its shades. Green
   up to 255: a capture 10% bright pushes it past 240. *)
let star_yellow : Cc.range =
  { low = { r = 200; g = 160; b = 0 }; high = { r = 255; g = 255; b = 150 } }

let probes =
  [ Solid_color.probe ~id:body_id body; Solid_color.probe ~id:strip_id strip ]
  @ List.init slots (fun i -> Cc.probe ~id:(badge_id i) (badge_box i) dark)
  @ List.init star_slots (fun k ->
        Cc.probe ~id:(star_id k) (star_box k) star_yellow)

type t = { badges : bool list; stars : int }

let earned t =
  List.concat
    (List.map2
       (fun name got -> if got then [ name ] else [])
       badge_names t.badges)

let hall_of_fame t = t.stars >= 1

let to_string t =
  let names = earned t in
  let badges =
    match names with
    | [] -> "no badge"
    | _ ->
        Printf.sprintf "%d badge%s (%s)" (List.length names)
          (if List.length names = 1 then "" else "s")
          (String.concat ", " names)
  in
  let stars =
    match t.stars with
    | 0 -> "no star"
    | 1 -> "1 star"
    | n -> Printf.sprintf "%d stars" n
  in
  badges ^ ", " ^ stars

let min_body_channel = 195.
let max_body_stddev_sum = 45.
let min_strip_sum = 450.
let max_strip_sum = 670.
let min_body_over_strip = 80.
let max_strip_stddev_sum = 60.
let min_badge_share = 0.04
let min_star_share = 0.15

let body_white (s : Solid_color.stats) =
  Float.min s.mean.r (Float.min s.mean.g s.mean.b) >= min_body_channel
  && Solid_color.sum s.stddev <= max_body_stddev_sum

let strip_colored (s : Solid_color.stats) =
  let sum = Solid_color.sum s.mean in
  sum >= min_strip_sum && sum <= max_strip_sum
  && Solid_color.sum s.stddev <= max_strip_stddev_sum

let front_shown m =
  match (Solid_color.read m body_id, Solid_color.read m strip_id) with
  | Some body, Some strip ->
      body_white body && strip_colored strip
      && Solid_color.sum body.mean -. Solid_color.sum strip.mean
         >= min_body_over_strip
  | _ -> false

let at_least share m id =
  Option.fold ~none:false ~some:(fun s -> s >= share) (Cc.share m id)

let read m =
  if not (front_shown m) then None
  else
    let badges =
      List.init slots (fun i -> at_least min_badge_share m (badge_id i))
    in
    let stars =
      List.length
        (List.filter
           (fun k -> at_least min_star_share m (star_id k))
           (List.init star_slots Fun.id))
    in
    Some { badges; stars }
