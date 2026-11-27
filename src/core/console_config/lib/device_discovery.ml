type capture_device = { index : string; device_id : string; name : string }

let serial_prefixes = [ "cu.usbmodem"; "cu.usbserial"; "ttyUSB"; "ttyACM" ]

let is_serial_device_name name =
  List.exists (fun prefix -> String.starts_with ~prefix name) serial_prefixes

let parse_capture_line line =
  match String.split_on_char '\t' (String.trim line) with
  | [ index; device_id; name ] when index <> "" ->
      Some { index; device_id; name }
  | [ index; name ] when index <> "" -> Some { index; device_id = ""; name }
  | _ -> None

let parse_capture_lines lines = List.filter_map parse_capture_line lines

let dev_entries () =
  if Sys.win32 || not (Sys.file_exists "/dev") then []
  else Sys.readdir "/dev" |> Array.to_list |> List.sort String.compare

let discover_serial_ports () =
  dev_entries ()
  |> List.filter is_serial_device_name
  |> List.map (fun name -> "/dev/" ^ name)

let linux_video_of_index name n =
  let dev = "/dev/" ^ name in
  { index = string_of_int n; device_id = dev; name = dev }

let parse_linux_video name =
  let prefix = "video" in
  let p = String.length prefix in
  if not (String.starts_with ~prefix name) then None
  else
    let suffix = String.sub name p (String.length name - p) in
    Option.map (linux_video_of_index name) (int_of_string_opt suffix)

let discover_macos_captures script =
  let cmd = Printf.sprintf "swift %s 2>/dev/null" (Filename.quote script) in
  let ic = Unix.open_process_in cmd in
  let lines = In_channel.input_lines ic in
  let _ = Unix.close_process_in ic in
  parse_capture_lines lines

let discover_capture_devices () =
  if Sys.win32 then []
  else
    match
      Repo_io.Repo_files.locate "daemon/tools/list_capture_devices.swift"
    with
    | Some script when Sys.file_exists "/usr/bin/swift" ->
        discover_macos_captures script
    | _ -> dev_entries () |> List.filter_map parse_linux_video

let alphabet_size = 26

let slot_label idx =
  if idx < alphabet_size then
    let lo = Char.chr (Char.code 'a' + idx) in
    let hi = Char.chr (Char.code 'A' + idx) in
    (Printf.sprintf "console-%c" lo, Printf.sprintf "Console %c" hi)
  else
    let n = idx + 1 in
    (Printf.sprintf "console-%d" n, Printf.sprintf "Console %d" n)

let suggest_consoles ~serials ~captures =
  let count = max (List.length serials) (List.length captures) in
  let rec build idx acc =
    if idx >= count then List.rev acc
    else
      let id, name = slot_label idx in
      let serial = List.nth_opt serials idx in
      let capture =
        match List.nth_opt captures idx with
        | Some c -> c.index
        | None -> string_of_int idx
      in
      let entry = (id, name, serial, capture) in
      build (idx + 1) (entry :: acc)
  in
  build 0 []
