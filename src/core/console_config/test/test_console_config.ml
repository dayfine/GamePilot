(* Console_config: JSON roundtrip, validation, upsert/remove, and --console flag
   expansion (tested on temp files, no hardware or daemon). *)

open Console_config

let case name input expectation : Table_test.case = { name; input; expectation }

let sample_switch =
  {
    id = "console-a";
    name = "Console A";
    backend = Switch { serial = Some "/dev/cu.usbserial-1"; capture = "Cam 1" };
  }

let sample_mgba =
  { id = "mgba"; name = "Local mGBA"; backend = Mgba { port = 47810 } }

let roundtrip () =
  let dir = Filename.temp_file "console_cfg_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "consoles.json" in
  let res =
    match save ~path [ sample_switch; sample_mgba ] with
    | Error e -> "save error: " ^ e
    | Ok () -> (
        match load ~path () with
        | Error e -> "load error: " ^ e
        | Ok cs -> String.concat " | " (List.map describe cs))
  in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Sys.rmdir dir;
  res

let expand_flag () =
  let dir = Filename.temp_file "console_exp_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "consoles.json" in
  let res =
    match save ~path [ sample_switch; sample_mgba ] with
    | Error e -> "save error: " ^ e
    | Ok () -> (
        match
          expand_console_flag ~path
            [ "--console"; "console-a"; "--from"; "su-01" ]
        with
        | Ok args -> String.concat " " args
        | Error e -> "error: " ^ e)
  in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Sys.rmdir dir;
  res

let unknown_flag () =
  let dir = Filename.temp_file "console_unk_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "consoles.json" in
  let res =
    match save ~path [ sample_mgba ] with
    | Error e -> "save error: " ^ e
    | Ok () -> (
        match expand_console_flag ~path [ "--console"; "missing" ] with
        | Ok _ -> "unexpected ok"
        | Error e -> e)
  in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Sys.rmdir dir;
  res

let () =
  Table_test.run "console_config"
    [
      case "save and load roundtrip" roundtrip
        "console-a (Console A): switch, serial=/dev/cu.usbserial-1, \
         capture=Cam 1 | mgba (Local mGBA): mgba, port=47810";
      case "expand --console injects backend flags before user flags"
        expand_flag
        "--backend switch --capture Cam 1 --serial /dev/cu.usbserial-1 --from \
         su-01";
      case "expand --console errors cleanly on unknown id" unknown_flag
        "unknown console \"missing\" (configured: mgba)";
      case "upsert replaces existing id"
        (fun () ->
          let updated =
            upsert [ sample_mgba ]
              {
                sample_mgba with
                name = "mGBA 2";
                backend = Mgba { port = 47811 };
              }
          in
          String.concat " | " (List.map describe updated))
        "mgba (mGBA 2): mgba, port=47811";
      case "remove drops matching id"
        (fun () ->
          let kept, removed = remove [ sample_switch; sample_mgba ] "mgba" in
          Printf.sprintf "%b:%d" removed (List.length kept))
        "true:1";
    ]
