let read m id =
  match Effects.probe m id with
  | Some (Wire.Color_count { fraction; _ }) -> Some fraction
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Template_ncc _
      | Wire.Line_shares _ | Wire.Find _ | Wire.Other _ )
  | None ->
      None
