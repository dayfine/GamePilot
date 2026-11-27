let probe ?template ~picture ~id box params =
  match (Native_box.probe_box ~picture box, params) with
  | Some box, Ok params ->
      [ Wire.find_probe ?template ~id ~box ~delivery:Every params ]
  | None, _ | _, Error _ -> []

let read m id =
  match Effects.probe m id with
  | Some (Wire.Find { blobs }) -> blobs
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Template_ncc _
      | Wire.Color_count _ | Wire.Line_shares _ | Wire.Other _ )
  | None ->
      []

type argb_range = { min : int; max : int }

let channel_bits = 8
let channel_mask = 0xff

let rgb v =
  let channel shift = (v lsr shift) land channel_mask in
  (channel (2 * channel_bits), channel channel_bits, channel 0)

let filter r : Wire.Blob_find.filter = { low = rgb r.min; high = rgb r.max }
