open Json_fields

type json = Yojson.Safe.t
type image_probes = string * (string * Probe.probe_result) list

let image_probes_of_json j =
  let what = "probe_images line" in
  ( string_field what "image" j,
    Probe.probes_of_json (what ^ ".probes") (field what "probes" j) )

let image_probes_of_string text =
  String.split_on_char '\n' text
  |> List.filter (fun line -> String.trim line <> "")
  |> List.map (fun line -> image_probes_of_json (parse_json line))

let read_image_probes path =
  image_probes_of_string (In_channel.with_open_bin path In_channel.input_all)
