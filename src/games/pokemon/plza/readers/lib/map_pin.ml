type point = { x : float; y : float }

let id = "map_pin"

(* The map's coordinates are the frame scaled to this. *)
let map_width = 800.
let map_height = 450.
let window_left = 240.
let window_right = 540.
let window_top = 170.
let window_bottom = 290.

let window =
  Native_box.of_fractions
    {
      left = window_left /. map_width;
      top = window_top /. map_height;
      width = (window_right -. window_left) /. map_width;
      height = (window_bottom -. window_top) /. map_height;
    }

let arrow_blue = [ Find_probe.filter { min = 0xff0080e1; max = 0xff40c0ff } ]
let min_area = 150.

let probes ~picture =
  Find_probe.probe ~picture ~id window
    (Wire.Blob_find.params ~filters:arrow_blue ~min_area ())

let area (b : Wire.Blob_find.blob) = b.fill *. b.w *. b.h

(* The first of equals, as the fork keeps the first blob of a size. *)
let largest blobs =
  List.fold_left
    (fun best (b : Wire.Blob_find.blob) ->
      match best with
      | Some (k : Wire.Blob_find.blob) when area b <= area k -> best
      | _ -> Some b)
    None blobs

let frame_width = float_of_int Native_box.frame_width
let frame_height = float_of_int Native_box.frame_height

(* The pin from the probe's blobs (frame pixels of the 1080p picture); for
    tests. *)
let of_blobs blobs =
  Option.map
    (fun (b : Wire.Blob_find.blob) ->
      {
        x = (b.x +. (b.w *. 0.5)) /. frame_width *. map_width;
        y = (b.y +. (b.h *. 0.5)) /. frame_height *. map_height;
      })
    (largest blobs)

let read m = of_blobs (Find_probe.read m id)
