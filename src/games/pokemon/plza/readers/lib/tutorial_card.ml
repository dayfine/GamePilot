let panel_id = "tutorial_card.panel"

let panel =
  Native_box.of_fractions
    { left = 0.32; top = 0.62; width = 0.36; height = 0.20 }

let edges =
  [
    ( "tutorial_card.left_edge",
      Native_box.of_fractions
        { left = 0.03; top = 0.30; width = 0.15; height = 0.40 } );
    ( "tutorial_card.right_edge",
      Native_box.of_fractions
        { left = 0.82; top = 0.30; width = 0.15; height = 0.40 } );
  ]

let channels = 3.

(* Not the fork's 225: a card a tenth dimmer averages 216; other panels
   185 at most. *)
let panel_min = 200.
let edge_max = 100.
let edge_max_stddev = 12.

let probes ~picture =
  List.concat_map
    (fun (id, b) -> Box_color.probe ~picture ~id b)
    ((panel_id, panel) :: edges)

let per_channel = Switch.Solid_color.sum

let dark_flat_edge m (id, _) =
  match Box_color.read m id with
  | Some s ->
      per_channel s.mean /. channels <= edge_max
      && per_channel s.stddev /. channels <= edge_max_stddev
  | None -> false

let shown m =
  match Box_color.read m panel_id with
  | Some s ->
      per_channel s.mean /. channels >= panel_min
      && List.for_all (dark_flat_edge m) edges
  | None -> false
