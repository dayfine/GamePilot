(* The fade a color_stats result shows. Ported from the fork's
   ScreenEvents_Tests (test_fade_of_screen): there each screen is a
   checkerboard of two colours, here its mean and stddev per channel. *)

open Screen_state

(* A checkerboard of two greys [a] and [b], as color_stats sees it. *)
let checkerboard a b =
  let grey v : Wire.rgb = { r = v; g = v; b = v } in
  Fade.name
    (Fade.of_color_stats
       ~mean:(grey ((a +. b) /. 2.))
       ~stddev:(grey (Float.abs (a -. b) /. 2.)))

let case name (a, b) expectation =
  { Case_table.name; input = (fun () -> checkerboard a b); expectation }

let () =
  Case_table.run "Fade.of_color_stats"
    [
      case "black" (0., 0.) "black fade";
      case "a cave mouth's dim fade (60 a channel)" (60., 60.) "black fade";
      case "white" (255., 255.) "white fade";
      case "grey, neither" (120., 120.) "no fade";
      case "a dark textured floor" (16., 80.) "no fade";
    ]
