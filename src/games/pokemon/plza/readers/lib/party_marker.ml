let slots = 6

(* Each slot's box on the frame: under its icon, where the marker shows. *)
let first_left = 0.048
let slot_pitch = 0.0398

let slot_box i =
  Native_box.of_fractions
    {
      left = first_left +. (slot_pitch *. float_of_int i);
      top = 0.926;
      width = 0.017;
      height = 0.058;
    }

(* The four markers: D-pad up and down, and their black insides. *)
let markers =
  Button_detector.
    [
      ("up", Dpad_up);
      ("down", Dpad_down);
      ("up_interior", Dpad_up_interior);
      ("down_interior", Dpad_down_interior);
    ]

let id (name, _) i = Printf.sprintf "party_marker.%s.%d" name i

let marker_probes ~picture ~assets ((_, button) as marker) i =
  Button_detector.probe ~picture ~assets ~id:(id marker i) button (slot_box i)

let probes ~picture ~assets =
  List.concat_map
    (fun marker ->
      List.concat (List.init slots (marker_probes ~picture ~assets marker)))
    markers

let in_slot m ((_, button) as marker) i =
  Button_detector.shown m (id marker i) button

let slot_shows m i = List.exists (fun marker -> in_slot m marker i) markers
let shown m = List.exists (slot_shows m) (List.init slots Fun.id)

let down_markers =
  List.filter
    (fun (_, button) ->
      button = Button_detector.Dpad_down
      || button = Button_detector.Dpad_down_interior)
    markers

let down_slot m =
  List.find_opt
    (fun i -> List.exists (fun marker -> in_slot m marker i) down_markers)
    (List.init slots Fun.id)
