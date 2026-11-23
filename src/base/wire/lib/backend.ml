open Json_fields

type json = Yojson.Safe.t

type backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
  width : int;
  height : int;
  viewport : Probe.box;
  game_width : int;
  game_height : int;
}

let backend_of_json j =
  let what = "hello.result.backend" in
  let game_size = field what "game_size" j in
  {
    kind = string_field what "kind" j;
    game_code = string_field what "game_code" j;
    frame_rate = float_field what "frame_rate" j;
    width = int_field what "width" j;
    height = int_field what "height" j;
    viewport = Probe.box_of_json (field what "viewport" j);
    game_width = int_field (what ^ ".game_size") "width" game_size;
    game_height = int_field (what ^ ".game_size") "height" game_size;
  }

let json_of_backend
    {
      kind;
      game_code;
      frame_rate;
      width;
      height;
      viewport;
      game_width;
      game_height;
    } =
  `Assoc
    [
      ("kind", `String kind);
      ("game_code", `String game_code);
      ("frame_rate", `Float frame_rate);
      ("width", `Int width);
      ("height", `Int height);
      ("viewport", Probe.json_of_box viewport);
      ( "game_size",
        `Assoc [ ("width", `Int game_width); ("height", `Int game_height) ] );
    ]

type hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}

let hello_result_of_json j =
  let what = "hello.result" in
  {
    protocol = int_field what "protocol" j;
    daemon = string_field what "daemon" j;
    backend = backend_of_json (field what "backend" j);
    probe_kinds =
      List.map (to_string "probe_kinds") (list_field what "probe_kinds" j);
  }

let json_of_hello_result { protocol; daemon; backend; probe_kinds } =
  `Assoc
    [
      ("protocol", `Int protocol);
      ("daemon", `String daemon);
      ("backend", json_of_backend backend);
      ("probe_kinds", json_of_strings probe_kinds);
    ]

type load_state_result = { seq : int; load : int }

let load_state_result_of_json j =
  let what = "backend.load_state.result" in
  { seq = int_field what "seq" j; load = int_field what "load" j }

let json_of_load_state_result { seq; load } =
  `Assoc [ ("seq", `Int seq); ("load", `Int load) ]
