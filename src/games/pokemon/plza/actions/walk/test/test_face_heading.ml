(* Facing a bearing by the minimap's arrow, as the C++'s tests check it
   ([face_heading] cases of PokemonLZA_AutoStoryActions_Tests.cpp,
   [plza/lean]): a game whose arrow follows the stick's turns, or does not,
   lags, or overshoots small turns. *)

open Plza_walk

let case name input expectation = { Table_test.name; input; expectation }

(* Below this, a turn lands [small_turn_scale] times as far as asked. *)
let small_turn = 15.

(* Faced: the player really faces the heading, not only the arrow read. *)
let faced_tolerance = 4.

type game = {
  mutable facing : float;
  mutable shown : float;
  mutable queued : float;
  mutable stale_left : int;
}

let degrees_of (s : Wire.stick) =
  let x, y = (s :> float * float) in
  Float.atan2 x y *. 180. /. Float.pi

let wrap a = Float.rem (Float.rem a 360. +. 360.) 360.

let face ?(turns_take = true) ?(stale_reads = 0) ?(small_turn_scale = 1.)
    ~facing heading () =
  let g = { facing; shown = facing; queued = 0.; stale_left = 0 } in
  let submit : Wire.command -> unit = function
    | Press { left_stick = Some s; _ } when turns_take ->
        let d = degrees_of s in
        g.queued <-
          (g.queued
          +. if Float.abs d < small_turn then d *. small_turn_scale else d)
    | _ -> ()
  in
  (* An observe, then the arrow: the old facing while the feed lags. *)
  let read_arrow () =
    if g.queued <> 0. then (
      g.shown <- g.facing;
      g.stale_left <- stale_reads);
    g.facing <- wrap (g.facing +. g.queued);
    g.queued <- 0.;
    if g.stale_left > 0 then (
      g.stale_left <- g.stale_left - 1;
      Some g.shown)
    else Some g.facing
  in
  let steps = { Face_heading.submit; read_arrow; log_detail = ignore } in
  match Face_heading.face steps heading with
  | Error c -> c.code
  | Ok () ->
      let off = Float.abs (Face_heading.turn_to g.facing heading) in
      if off <= faced_tolerance then "faced"
      else Printf.sprintf "the arrow faced, the player %.0f" g.facing

let cases =
  [
    case "run 10 of 03.08: from 135 to west" (face ~facing:135. 270.) "faced";
    case "across north" (face ~facing:350. 20.) "faced";
    case
      "8 off is not facing it: 03.09 read 272 for 264 and walked right of the \
       gate"
      (face ~turns_take:false ~facing:272. 264.)
      "heading_missed";
    (* Korean 03.08 catch_more_species read 161, 163, 269, 9, 9 for 265: each
       reading one turn late (console B video, 2026-11-17 23:58). *)
    case "a lagging feed: from 161 to 265"
      (face ~stale_reads:1 ~facing:161. 265.)
      "faced";
    (* CHS 03.08 read 248.9, 259.1, 249.1, 259.3 for 254: each 5 deg
       correction turned 10 (console B, 2026-11-18 02:03). *)
    case "small turns overshoot: from 249 to 254"
      (face ~small_turn_scale:2. ~facing:249. 254.)
      "faced";
    case "no arrow for 40 s: arrow_unread"
      (fun () ->
        let steps =
          {
            Face_heading.submit = ignore;
            read_arrow = (fun () -> None);
            log_detail = ignore;
          }
        in
        match Face_heading.face steps 90. with
        | Error c -> c.code
        | Ok () -> "faced")
      "arrow_unread";
  ]

let () = Table_test.run "plza_face_heading" cases
