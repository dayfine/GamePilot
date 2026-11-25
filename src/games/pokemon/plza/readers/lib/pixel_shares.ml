open Wire.Line_shares

let sky_blue =
  [
    { weights = (0, 0, 1); op = Greater; value = 200 };
    { weights = (0, 1, 0); op = Greater; value = 160 };
    { weights = (-1, 0, 1); op = Greater; value = 60 };
  ]

let cyan =
  [
    { weights = (-1, 0, 1); op = Greater; value = 50 };
    { weights = (-1, 1, 0); op = Greater; value = 30 };
    { weights = (0, 0, 1); op = Greater; value = 120 };
    { weights = (0, -1, 1); op = Greater_equal; value = -20 };
  ]

let dim_cyan =
  [
    { weights = (-1, 0, 1); op = Greater; value = 40 };
    { weights = (-1, 1, 0); op = Greater; value = 25 };
    { weights = (0, 0, 1); op = Greater; value = 70 };
    { weights = (0, -1, 1); op = Greater_equal; value = -20 };
  ]

let white =
  [
    { weights = (1, 0, 0); op = Greater; value = 200 };
    { weights = (0, 1, 0); op = Greater; value = 200 };
    { weights = (0, 0, 1); op = Greater; value = 200 };
  ]

let probe ~picture ~id box test =
  match Native_box.probe_box ~picture box with
  | Some box ->
      Result.to_list (Wire.line_shares_probe ~id ~box ~delivery:Every ~test)
  | None -> []

let lines m id =
  match Effects.probe m id with
  | Some (Wire.Line_shares t) -> Some t
  | Some
      ( Wire.Color_stats _ | Wire.Template_match _ | Wire.Color_count _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let window shares ~first ~count =
  let picked =
    List.filteri (fun i _ -> i >= first && i < first + count) shares
  in
  if first < 0 || count <= 0 || List.length picked <> count then None
  else Some (List.fold_left ( +. ) 0. picked /. float_of_int count)
