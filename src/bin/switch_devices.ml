(* gamepilot switch-devices [--profile DIR]

   Prints the controller board's serial port and the capture card the lab app
   uses for one console, read from that console's lab profile (DIR, default
   $GAMEPILOT_LAB_PROFILE: the SerialPrograms profile folder, e.g. its lab-B),
   and the flags gamepilot would pass the daemon. Reads the settings file
   only; opens no device.

   The lab app keeps, per program panel, ConsoleSetup.Controller["Serial:
   PABotBase2"] (the port's name under /dev) and ConsoleSetup.Video.Camera (the
   card's AVFoundation unique id), and in GlobalSettings.DEVICE_ALIASES each
   card's name. OpenCV opens a card by index, not by id or name (two cards may
   share a name), so the index is looked up on the console with
   tools/list_capture_devices.swift. *)

let usage = "  gamepilot switch-devices [--profile DIR]\n"
let settings_file = [ "UserSettings"; "SerialPrograms-Settings.json" ]

(* The panel whose console setup the lab runs FRLG with. *)
let panel = "PokemonFRLG:AutoStory"
let utf8_bom = "\xef\xbb\xbf"

let read_settings dir =
  let path = List.fold_left Filename.concat dir settings_file in
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> (
      let n = String.length utf8_bom in
      let text =
        if String.starts_with ~prefix:utf8_bom text then
          String.sub text n (String.length text - n)
        else text
      in
      try Ok (Yojson.Safe.from_string text)
      with Yojson.Json_error e -> Error (path ^ ": " ^ e))
  | exception Sys_error e -> Error e

let rec member_path json = function
  | [] -> Some json
  | key :: rest -> (
      match json with
      | `Assoc fields ->
          Option.bind (List.assoc_opt key fields) (fun v -> member_path v rest)
      | _ -> None)

let string_at json path =
  match member_path json path with Some (`String s) -> Some s | _ -> None

(* The lab app's video cards: (unique id, name) from its device aliases. *)
let video_cards json =
  let card alias =
    match
      ( string_at alias [ "category" ],
        string_at alias [ "device_id" ],
        string_at alias [ "device_name" ] )
    with
    | Some "Video", Some id, Some name -> Some (id, name)
    | _ -> None
  in
  match member_path json [ "20-GlobalSettings"; "DEVICE_ALIASES" ] with
  | Some (`List aliases) -> List.filter_map card aliases
  | _ -> []

let serial_path name =
  if String.starts_with ~prefix:"/dev/" name then name else "/dev/" ^ name

(* How many distinct cards are called [name]. *)
let cards_named cards name =
  let id_if_named (id, n) = if n = name then Some id else None in
  List.length (List.sort_uniq compare (List.filter_map id_if_named cards))

let print_devices json ~serial ~camera =
  let cards = video_cards json in
  let name = Option.value (List.assoc_opt camera cards) ~default:"(no name)" in
  Printf.printf "serial port: %s\n" (serial_path serial);
  Printf.printf "capture card: id %s, named %S" camera name;
  let shared = cards_named cards name in
  if shared > 1 then Printf.printf " (%d cards have that name)" shared;
  print_newline ();
  Printf.printf
    "daemon flags: --backend switch --serial %s --capture INDEX\n\
     INDEX: the line of `swift tools/list_capture_devices.swift` with id %s\n"
    (serial_path serial) camera

let devices dir =
  let ( let* ) = Result.bind in
  let* json = read_settings dir in
  let setup = [ "99-Panels"; panel; "ConsoleSetup" ] in
  match
    ( string_at json (setup @ [ "Controller"; "Serial: PABotBase2" ]),
      string_at json (setup @ [ "Video"; "Camera" ]) )
  with
  | Some serial, Some camera when serial <> "" && camera <> "" ->
      Printf.printf "lab profile %s, panel %s\n" dir panel;
      print_devices json ~serial ~camera;
      Ok 0
  | _ -> Error ("no serial port or camera in " ^ panel ^ "'s console setup")

let main = function
  | [ "--profile"; dir ] -> devices dir
  | [] -> (
      match Sys.getenv_opt "GAMEPILOT_LAB_PROFILE" with
      | Some dir when dir <> "" -> devices dir
      | _ -> Error "set GAMEPILOT_LAB_PROFILE or pass --profile DIR")
  | a :: _ -> Error ("unknown argument " ^ a)
