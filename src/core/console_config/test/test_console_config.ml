(* Console_config: JSON roundtrip, validation, upsert/remove, and --console flag
   expansion (tested on temp files, no hardware or daemon). *)

open Console_config

let case name input expectation : Table_test.case = { name; input; expectation }

let sample_switch =
  {
    id = "console-a";
    name = "Console A";
    backend = Switch { serial = Some "/dev/cu.usbserial-1"; capture = "Cam 1" };
    watch_port = None;
  }

let sample_switch_watched =
  {
    id = "console-b";
    name = "Console B";
    backend = Switch { serial = Some "/dev/cu.usbserial-2"; capture = "Cam 2" };
    watch_port = Some 47910;
  }

let sample_mgba =
  {
    id = "mgba";
    name = "Local mGBA";
    backend = Mgba { port = 47810 };
    watch_port = None;
  }

let sample_mgba_watched =
  {
    id = "mgba-w";
    name = "Watched mGBA";
    backend = Mgba { port = 47812 };
    watch_port = Some 47912;
  }

let with_temp_config consoles f =
  let dir = Filename.temp_file "console_cfg_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "consoles.json" in
  let res =
    match save ~path consoles with
    | Error e -> "save error: " ^ e
    | Ok () -> f path
  in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Sys.rmdir dir;
  res

let roundtrip () =
  with_temp_config [ sample_switch; sample_mgba ] (fun path ->
      match load ~path () with
      | Error e -> "load error: " ^ e
      | Ok cs -> String.concat " | " (List.map describe cs))

let roundtrip_watch_port () =
  with_temp_config [ sample_switch_watched; sample_switch; sample_mgba_watched ]
    (fun path ->
      match load ~path () with
      | Error e -> "load error: " ^ e
      | Ok cs -> String.concat " | " (List.map describe cs))

let decode_legacy_without_watch_port () =
  let json =
    Yojson.Safe.from_string
      {|{"consoles":[{"id":"console-a","name":"Console A","backend":"switch","capture":"0","serial":"/dev/cu.usbserial-1"}]}|}
  in
  match of_json json with
  | Ok [ c ] ->
      Printf.sprintf "%s:%b" (describe c) (Option.is_none c.watch_port)
  | Ok _ -> "unexpected count"
  | Error e -> "error: " ^ e

let decode_bad_watch_port raw () =
  let json =
    Yojson.Safe.from_string
      (Printf.sprintf
         {|{"consoles":[{"id":"mgba","name":"mGBA","backend":"mgba","watch_port":%s}]}|}
         raw)
  in
  match of_json json with Ok _ -> "unexpected ok" | Error e -> e

let expand_with ?(env_console_id = None) consoles args () =
  with_temp_config consoles (fun path ->
      match expand_console_flag ~path ~env_console_id args with
      | Ok out -> String.concat " " out
      | Error e -> "error: " ^ e)

let resolve_case ?(env_console_id = None) consoles explicit () =
  with_temp_config consoles (fun path ->
      match resolve ~path ~env_console_id explicit with
      | Ok c -> describe c
      | Error e -> "error: " ^ e)

let () =
  let all_consoles =
    [ sample_switch; sample_switch_watched; sample_mgba; sample_mgba_watched ]
  in
  Table_test.run "console_config"
    [
      case "save and load roundtrip" roundtrip
        "console-a (Console A): switch, serial=/dev/cu.usbserial-1, \
         capture=Cam 1 | mgba (Local mGBA): mgba, port=47810";
      case "save and load roundtrip with watch_port present and omitted"
        roundtrip_watch_port
        "console-b (Console B): switch, serial=/dev/cu.usbserial-2, \
         capture=Cam 2, watch_port=47910 | console-a (Console A): switch, \
         serial=/dev/cu.usbserial-1, capture=Cam 1 | mgba-w (Watched mGBA): \
         mgba, port=47812, watch_port=47912";
      case "decodes legacy consoles.json without watch_port"
        decode_legacy_without_watch_port
        "console-a (Console A): switch, serial=/dev/cu.usbserial-1, \
         capture=0:true";
      case "rejects out-of-range watch_port"
        (decode_bad_watch_port "70000")
        "consoles[0]: watch_port is 70000, not 1..65535";
      case "rejects non-integer watch_port"
        (decode_bad_watch_port {|"47910"|})
        "consoles[0]: watch_port is not an integer";
      case "expand --console injects backend flags before user flags"
        (expand_with
           [ sample_switch; sample_mgba ]
           [ "--console"; "console-a"; "--from"; "su-01" ])
        "--backend switch --capture Cam 1 --serial /dev/cu.usbserial-1 --from \
         su-01";
      case "expand --console with --watch injects configured watch_port"
        (expand_with all_consoles
           [ "--console"; "console-b"; "--watch"; "--from"; "su-01" ])
        "--backend switch --capture Cam 2 --serial /dev/cu.usbserial-2 \
         --watch-port 47910 --watch --from su-01";
      case "expand --console with --listen injects configured watch_port"
        (expand_with all_consoles
           [ "--console"; "console-b"; "--listen"; "0.0.0.0" ])
        "--backend switch --capture Cam 2 --serial /dev/cu.usbserial-2 \
         --watch-port 47910 --listen 0.0.0.0";
      case "expand --console without --watch omits watch_port"
        (expand_with all_consoles [ "--console"; "console-b"; "--preflight" ])
        "--backend switch --capture Cam 2 --serial /dev/cu.usbserial-2 \
         --preflight";
      case "expand --console keeps explicit --watch-port"
        (expand_with all_consoles
           [ "--console"; "console-b"; "--watch"; "--watch-port"; "48000" ])
        "--backend switch --capture Cam 2 --serial /dev/cu.usbserial-2 --watch \
         --watch-port 48000";
      case "expand resolves watch_port by matching --serial and --capture"
        (expand_with all_consoles
           [
             "--backend";
             "switch";
             "--serial";
             "/dev/cu.usbserial-2";
             "--capture";
             "Cam 2";
             "--watch";
           ])
        "--watch-port 47910 --backend switch --serial /dev/cu.usbserial-2 \
         --capture Cam 2 --watch";
      case "expand resolves watch_port from GAMEPILOT_CONSOLE_ID"
        (expand_with ~env_console_id:(Some "console-b") all_consoles
           [ "--watch"; "--from"; "su-01" ])
        "--watch-port 47910 --watch --from su-01";
      case "expand prefers --serial/--capture match over GAMEPILOT_CONSOLE_ID"
        (expand_with ~env_console_id:(Some "console-a") all_consoles
           [
             "--backend";
             "switch";
             "--serial";
             "/dev/cu.usbserial-2";
             "--capture";
             "Cam 2";
             "--watch";
           ])
        "--watch-port 47910 --backend switch --serial /dev/cu.usbserial-2 \
         --capture Cam 2 --watch";
      case "expand resolves watch_port by matching --mgba-port"
        (expand_with all_consoles [ "--mgba-port"; "47812"; "--watch" ])
        "--watch-port 47912 --mgba-port 47812 --watch";
      case "expand --console errors cleanly on unknown id"
        (expand_with [ sample_mgba ] [ "--console"; "missing" ])
        "error: unknown console \"missing\" (configured: mgba)";
      case "resolve falls back to GAMEPILOT_CONSOLE_ID"
        (resolve_case ~env_console_id:(Some "console-b") all_consoles None)
        "console-b (Console B): switch, serial=/dev/cu.usbserial-2, \
         capture=Cam 2, watch_port=47910";
      case "resolve errors when neither --console nor env is set"
        (resolve_case all_consoles None)
        "error: specify --console ID or set GAMEPILOT_CONSOLE_ID";
      case "effective_watch_port prefers explicit, then configured, else 0"
        (fun () ->
          Printf.sprintf "%d:%d:%d"
            (effective_watch_port ~explicit:(Some 49000) sample_switch_watched)
            (effective_watch_port ~explicit:None sample_switch_watched)
            (effective_watch_port ~explicit:None sample_switch))
        "49000:47910:0";
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
      case "device discovery filters serial names"
        (fun () ->
          let names =
            [
              "cu.usbmodem5C630032771";
              "cu.Bluetooth-Incoming-Port";
              "ttyUSB0";
              "disk0";
            ]
          in
          String.concat ","
            (List.filter Device_discovery.is_serial_device_name names))
        "cu.usbmodem5C630032771,ttyUSB0";
      case "device discovery parses capture list and suggests consoles"
        (fun () ->
          let captures =
            Device_discovery.parse_capture_lines
              [ "0\t0x1100\tUSB Video"; "1\t0x1140\tUSB Video" ]
          in
          let suggested =
            Device_discovery.suggest_consoles
              ~serials:[ "/dev/cu.usbmodemA"; "/dev/cu.usbmodemB" ]
              ~captures
          in
          String.concat " | "
            (List.map
               (fun (id, name, ser, cap) ->
                 Printf.sprintf "%s:%s:%s:%s" id name
                   (Option.value ser ~default:"none")
                   cap)
               suggested))
        "console-a:Console A:/dev/cu.usbmodemA:0 | console-b:Console \
         B:/dev/cu.usbmodemB:1";
    ]
