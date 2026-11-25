type t = {
  width : int;
  height : int;
  fill : float;
  aspect_lower : float;
  aspect_upper : float;
  fill_lower : float;
  fill_upper : float;
}

let within low high v = low <= v && v <= high

let aspect_ok t (blob : Wire.Blob_find.blob) =
  within t.aspect_lower t.aspect_upper
    (float_of_int t.width *. blob.h /. (float_of_int t.height *. blob.w))

let fill_ok t (blob : Wire.Blob_find.blob) =
  t.fill = 0. || within t.fill_lower t.fill_upper (blob.fill /. t.fill)

let matches t ~max_score (blob : Wire.Blob_find.blob) =
  match blob.score with
  | Some score -> aspect_ok t blob && fill_ok t blob && score < max_score
  | None -> false
