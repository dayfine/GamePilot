let id = "advance_arrow"

(* x 1370-1480, y 930-1050. *)
let area : Native_box.t = { x = 1370; y = 930; w = 110; h = 120 }

(* The fork's white (blue from 220: JPEG loses blue at the edges of white over
   orange) and dark, and between them a dimmer white of our own: a white
   chevron dimmed by a tenth (255 to 230) falls out of the fork's white. *)
let filters =
  List.map Find_probe.filter
    Find_probe.
      [
        { min = 0x00ebebdc; max = 0xffffffff };
        { min = 0x00d7d7c8; max = 0xffffffff };
        { min = 0x00000000; max = 0xff6e6e6e };
      ]

(* 26-40 by 15-24 (1080p pixels), aspect 1.4-2.1, strays within 4 pixels at
   most 0.09 of its pixels; the V overlapped 0.51 at least, not the fork's
   0.45. Headroom on the test frames and their shifted versions
   (test_dialog_readers.ml): chevrons overlap 0.53 at least, the glowing blade
   on 0033 0.49 at most (in the dimmer white; 0.48 in the fork's own), which
   0.45 would let through. *)
let min_width = 26.
let min_height = 15.
let max_width = 40.
let max_height = 24.
let min_aspect = 1.4
let max_aspect = 2.1
let stray_margin = 4.
let max_stray = 0.09
let min_overlap = 0.51

let probes ~picture ~(assets : Blob_assets.t) =
  Find_probe.probe ~picture ~id area
    (Wire.Blob_find.params ~min_size:(min_width, min_height)
       ~max_size:(max_width, max_height) ~margin:stray_margin
       ~shape:assets.advance_chevron_shape ~filters ~min_area:1. ())

let chevron (blob : Wire.Blob_find.blob) =
  let aspect = blob.w /. blob.h in
  match (blob.stray, blob.overlap) with
  | Some stray, Some overlap ->
      aspect >= min_aspect && aspect <= max_aspect && stray <= max_stray
      && overlap >= min_overlap
  | None, _ | _, None -> false

let shown m = List.exists chevron (Find_probe.read m id)
