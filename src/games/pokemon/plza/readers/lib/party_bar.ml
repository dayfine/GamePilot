(* The last slot's frame on the 1080p frame: x 458, y 954, 66 px square, its
   line 2 px wide; 3 px strips 2 px off the line on either side, read along
   each edge's middle, 8 px clear of the rounded corners. *)
let last_slot_x = 458
let slot_frame_y = 954
let slot_frame_size = 66
let frame_line = 2
let frame_strip = 3
let frame_gap = 2
let frame_corner = 8
let inside_margin = 10.0
let outside_margin = 0.0

(* The mean of a box's three channels. *)
let channels = 3.0

type edge = {
  line : Native_box.t;
  inside : Native_box.t;
  outside : Native_box.t;
}

let span = slot_frame_size - (2 * frame_corner)
let step = frame_line + frame_gap
let left = last_slot_x
let right = last_slot_x + slot_frame_size - frame_line
let top = slot_frame_y
let bottom = slot_frame_y + slot_frame_size - frame_line
let across ~x ~y : Native_box.t = { x; y; w = span; h = frame_line }
let strip_across ~x ~y : Native_box.t = { x; y; w = span; h = frame_strip }
let down ~x ~y : Native_box.t = { x; y; w = frame_line; h = span }
let strip_down ~x ~y : Native_box.t = { x; y; w = frame_strip; h = span }
let mid_x = left + frame_corner
let mid_y = top + frame_corner

let edges =
  [
    ( "top",
      {
        line = across ~x:mid_x ~y:top;
        inside = strip_across ~x:mid_x ~y:(top + step);
        outside = strip_across ~x:mid_x ~y:(top - frame_gap - frame_strip);
      } );
    ( "bottom",
      {
        line = across ~x:mid_x ~y:bottom;
        inside = strip_across ~x:mid_x ~y:(bottom - frame_gap - frame_strip);
        outside = strip_across ~x:mid_x ~y:(bottom + step);
      } );
    ( "left",
      {
        line = down ~x:left ~y:mid_y;
        inside = strip_down ~x:(left + step) ~y:mid_y;
        outside = strip_down ~x:(left - frame_gap - frame_strip) ~y:mid_y;
      } );
    ( "right",
      {
        line = down ~x:right ~y:mid_y;
        inside = strip_down ~x:(right - frame_gap - frame_strip) ~y:mid_y;
        outside = strip_down ~x:(right + step) ~y:mid_y;
      } );
  ]

let id edge part = Printf.sprintf "party_bar.%s.%s" edge part
let parts e = [ ("line", e.line); ("inside", e.inside); ("outside", e.outside) ]

let empty_slot_probes ~picture =
  List.concat_map
    (fun (name, e) ->
      List.concat_map
        (fun (part, box) -> Box_color.probe ~picture ~id:(id name part) box)
        (parts e))
    edges

let brightness m edge part =
  Option.map
    (fun (s : Box_color.stats) ->
      Switch_home.Solid_color.sum s.mean /. channels)
    (Box_color.read m (id edge part))

type margin = { inside : float; outside : float }

let edge_margin m (name, _) =
  match
    ( brightness m name "line",
      brightness m name "inside",
      brightness m name "outside" )
  with
  | Some line, Some inside, Some outside ->
      Some { inside = line -. inside; outside = line -. outside }
  | _ -> None

let margins m =
  let read = List.map (edge_margin m) edges in
  if List.for_all Option.is_some read then Some (List.filter_map Fun.id read)
  else None

let clears (g : margin) =
  g.inside >= inside_margin && g.outside >= outside_margin

let last_slot_empty m =
  match margins m with Some gs -> List.for_all clears gs | None -> false

let probes ~picture ~assets =
  empty_slot_probes ~picture @ Party_marker.probes ~picture ~assets

let shown m = Party_marker.shown m || last_slot_empty m
