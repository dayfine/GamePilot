(* Ui_api: pure JSON encoding of Program_registry, launch request decoding, and
   gamepilot run argv construction (no sockets or child processes). *)

open Ui_hub

let case name input expectation : Table_test.case = { name; input; expectation }

let sample_console : Console_config.console =
  {
    id = "console-a";
    name = "Console A";
    backend = Switch { serial = Some "/dev/cu.usbserial-1"; capture = "0" };
  }

let build_run json () =
  match Ui_api.decode_launch (Yojson.Safe.from_string json) with
  | Error e -> "decode error: " ^ e
  | Ok req -> (
      match
        Ui_api.build_run_argv ~gamepilot:"gamepilot" ~console:sample_console req
      with
      | Ok argv -> String.concat " " argv
      | Error e -> "build error: " ^ e)

let programs_has_supplies () =
  match Ui_api.programs_json () with
  | `Assoc [ ("programs", `List items) ] ->
      let has =
        List.exists
          (function
            | `Assoc fields ->
                List.assoc_opt "id" fields = Some (`String "frlg.supplies")
            | _ -> false)
          items
      in
      string_of_bool has
  | _ -> "bad shape"

let () =
  Table_test.run "ui_api"
    [
      case "programs_json includes frlg.supplies" programs_has_supplies "true";
      case "build_run_argv for frlg.supplies with options"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","from":"su-01","to":"su-01","options":{"retro-mail":"20","super-repel":"0"}}|})
        "gamepilot run frlg.supplies --backend switch --capture 0 --serial \
         /dev/cu.usbserial-1 --from su-01 --to su-01 --mode testing --watch \
         --options retro-mail=20 --options super-repel=0";
      case "build_run_argv for preflight omits --watch"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","from":"su-01","preflight":true}|})
        "gamepilot run frlg.supplies --backend switch --capture 0 --serial \
         /dev/cu.usbserial-1 --preflight --from su-01 --options retro-mail=100 \
         --options super-repel=5";
      case "build_run_argv rejects invalid option value"
        (build_run
           {|{"console":"console-a","program":"frlg.supplies","options":{"retro-mail":"9999"}}|})
        "build error: --options retro-mail=9999: retro-mail is 0 to 999";
      case "external_runs parses daemon line and skips hub"
        (fun () ->
          let lines =
            [
              "56269 /path/gamepilot_daemon --hub --watch-port 47901";
              "80610 /path/gamepilot_daemon --backend switch --serial \
               /dev/cu.usbserial-1 --checkpoint bdsp.underground --registry \
               /tmp/watch";
            ]
          in
          let runs = External_runs.parse_ps_lines lines in
          match External_runs.match_console runs sample_console with
          | Some r ->
              Printf.sprintf "%d:%s:%s" r.pid r.program
                (Option.value r.registry ~default:"")
          | None -> "none")
        "80610:bdsp.underground:/tmp/watch";
    ]
