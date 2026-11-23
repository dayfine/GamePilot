(* Decodes and re-encodes every golden file in contracts/v1; the result must be
   the same JSON value (number spelling and key order aside). *)

(* contracts/ sits outside the dune project, so find it from the build dir. *)
let contracts_dir () =
  let rec up dir =
    let candidate = Filename.concat (Filename.concat dir "contracts") "v1" in
    if Sys.file_exists candidate && Sys.is_directory candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then failwith "contracts/v1 not found above the test dir"
      else up parent
  in
  up (Sys.getcwd ())

let rec json_equal (a : Yojson.Safe.t) (b : Yojson.Safe.t) =
  match (a, b) with
  | (`Int _ | `Float _), (`Int _ | `Float _) ->
      let f = function `Int i -> float_of_int i | `Float f -> f | _ -> nan in
      f a = f b
  | `Assoc x, `Assoc y ->
      let sort = List.sort (fun (k, _) (l, _) -> compare k l) in
      List.length x = List.length y
      && List.for_all2
           (fun (k, v) (l, w) -> k = l && json_equal v w)
           (sort x) (sort y)
  | `List x, `List y ->
      List.length x = List.length y && List.for_all2 json_equal x y
  | _ -> a = b

(* Typed codecs for successful responses, by the method of the request with
   the same id (responses do not name their method). *)
let result_round_trips =
  [
    ("hello", fun j -> Wire.(json_of_hello_result (hello_result_of_json j)));
    ( "backend.load_state",
      fun j -> Wire.(json_of_load_state_result (load_state_result_of_json j)) );
    ( "probe.upload_template",
      fun j ->
        Wire.(json_of_upload_template_result (upload_template_result_of_json j))
    );
    ( "subscribe",
      fun j -> Wire.(json_of_subscribe_result (subscribe_result_of_json j)) );
    ( "unsubscribe",
      fun j -> Wire.(json_of_unsubscribe_result (unsubscribe_result_of_json j))
    );
    ("submit", fun j -> Wire.(json_of_submit_result (submit_result_of_json j)));
    ("cancel", fun j -> Wire.(json_of_cancel_result (cancel_result_of_json j)));
  ]

let read_golden dir file =
  Yojson.Safe.from_string
    (In_channel.with_open_bin (Filename.concat dir file) In_channel.input_all)

(* Request id -> method, from every golden request. *)
let methods_by_id dir files =
  List.filter_map
    (fun file ->
      match Wire.message_of_json (read_golden dir file) with
      | Wire.Request { id; call } -> Some (id, Wire.method_name call)
      | _ | (exception Wire.Decode_error _) -> None)
    files

let check_file dir methods file =
  let golden = read_golden dir file in
  let reencoded =
    if Filename.check_suffix file ".line.json" then
      Wire.(json_of_log_line (log_line_of_json golden))
    else Wire.(json_of_message (message_of_json golden))
  in
  if not (json_equal golden reencoded) then
    failwith
      (Printf.sprintf "%s: re-encoded differs:\n  golden %s\n  ours   %s" file
         (Yojson.Safe.to_string golden)
         (Yojson.Safe.to_string reencoded));
  (match Wire.message_of_json golden with
  | Wire.Response { id; outcome = Ok result } -> (
      let m =
        match List.assoc_opt id methods with
        | Some m -> m
        | None -> failwith (Printf.sprintf "%s: no request with id %d" file id)
      in
      match List.assoc_opt m result_round_trips with
      | None -> failwith (file ^ ": no typed result codec for " ^ m)
      | Some round_trip ->
          if not (json_equal result (round_trip result)) then
            failwith (file ^ ": typed result does not round-trip"))
  | _ | (exception Wire.Decode_error _) -> ());
  Printf.printf "ok %s\n" file

(* The golden upload carries the 3x2 PNG's bytes, and its spec names the hash
   the golden response returned. *)
let check_template_upload dir =
  (match
     Wire.message_of_json (read_golden dir "15-upload_template.request.json")
   with
  | Wire.Request { call = Wire.Upload_template { png }; _ } ->
      if String.sub png 1 3 <> "PNG" then failwith "FAILED upload is not a PNG"
  | _ -> failwith "FAILED upload request decoded as something else");
  let hash =
    Wire.upload_template_result_of_json
      (Yojson.Safe.Util.member "result"
         (read_golden dir "16-upload_template.response.json"))
  in
  (match
     Wire.message_of_json
       (read_golden dir "17-subscribe.template_match.request.json")
   with
  | Wire.Request { call = Wire.Subscribe [ cursor; word ]; _ } ->
      let box = { Wire.x = 0.5; y = 0.0; w = 0.5; h = 0.25 } in
      if
        cursor
        <> Wire.template_match_probe ~id:"cursor" ~box ~delivery:Latest
             ~template:hash ()
      then failwith "FAILED template subscribe differs from the constructor";
      let box = { Wire.x = 0.38333; y = 0.1625; w = 0.425; h = 0.1 } in
      let ink = { Wire.min = (0, 0, 0); max = (144, 144, 255) } in
      if
        word
        <> Wire.template_match_probe ~ink ~id:"bag.1/TM CASE" ~box
             ~delivery:Latest ~template:hash ()
      then failwith "FAILED ink subscribe differs from the constructor"
  | _ -> failwith "FAILED template subscribe decoded as something else");
  (* Wrong length, '=' inside, padding before the end, a char outside the
     alphabet. *)
  List.iter
    (fun text ->
      match
        Wire.message_of_string
          (Printf.sprintf
             {|{"jsonrpc":"2.0","id":1,"method":"probe.upload_template","params":{"png":%S}}|}
             text)
      with
      | _ -> failwith ("FAILED bad base64 decoded: " ^ text)
      | exception Wire.Decode_error _ -> ())
    [ "TWF"; "TW=u"; "TQ==TWFu"; "T!Fu" ];
  print_endline "ok template upload"

let check_probe_constructors () =
  let box = { Wire.x = 0.; y = 0.; w = 1.; h = 1. } in
  let spec = Wire.color_stats_probe ~id:"p" ~box ~delivery:Every in
  if spec.kind <> "core.color_stats@1" || spec.template <> None then
    failwith "FAILED color stats constructor";
  (* Bytes of every value survive base64, whatever the padding. *)
  List.iter
    (fun png ->
      let call = Wire.Upload_template { png } in
      match
        Wire.message_of_string
          (Wire.string_of_message (Wire.Request { id = 1; call }))
      with
      | Wire.Request { call = c; _ } when c = call -> ()
      | _ -> failwith "FAILED upload round trip")
    [ ""; "\x00"; "\xff\xfe"; "PNG"; "\x89PNG\r\n" ];
  print_endline "ok probe constructors and upload round trip"

(* The golden color count subscribe is what the constructor builds; in its
   frame the line without red pixels has no mean and the other one has. A
   range needs both ends. *)
let check_color_count dir =
  (match
     Wire.message_of_json
       (read_golden dir "19-subscribe.color_count.request.json")
   with
  | Wire.Request { call = Wire.Subscribe [ first; _ ]; _ } ->
      let box = { Wire.x = 0.0625; y = 0.75; w = 0.875; h = 0.09375 } in
      if
        first
        <> Wire.color_count_probe ~id:"arrow_line1" ~box ~delivery:Every
             ~min:(160, 0, 0) ~max:(255, 120, 120)
      then failwith "FAILED color count subscribe differs from the constructor"
  | _ -> failwith "FAILED color count subscribe decoded as something else");
  (match
     Wire.message_of_json
       (read_golden dir "20-frame.color_count.notification.json")
   with
  | Wire.Notification
      (Wire.Frame
         {
           frame =
             {
               probes =
                 [
                   ("arrow_line1", Wire.Color_count { mean = None; _ });
                   ( "arrow_line2",
                     Wire.Color_count { mean = Some { r = 224.; _ }; _ } );
                 ];
               _;
             };
           _;
         }) ->
      ()
  | _ -> failwith "FAILED color count frame decoded wrong");
  (match
     Wire.message_of_string
       {|{"jsonrpc":"2.0","id":1,"method":"subscribe","params":{"probes":[{"id":"p","kind":"core.color_count@1","box":{"x":0,"y":0,"w":1,"h":1},"delivery":"every","min":[0,0,0]}]}}|}
   with
  | _ -> failwith "FAILED color count without max decoded"
  | exception Wire.Decode_error _ -> ());
  print_endline "ok color count"

(* probe_images prints one line per image; blank lines (a trailing newline)
   are skipped and each probes map decodes like a frame's. *)
let check_image_probes () =
  let text =
    {|{"image":"a.png","probes":{"bg":{"kind":"core.color_stats@1","mean":[1,2,3],"stddev":[0,0,0]}}}
{"image":"b.png","probes":{"cursor":{"kind":"core.template_match@1","score":0.5,"x":0.25,"y":0}}}
|}
  in
  (match Wire.image_probes_of_string text with
  | [
   ("a.png", [ ("bg", Wire.Color_stats { mean = { r = 1.; _ }; _ }) ]);
   ("b.png", [ ("cursor", Wire.Template_match { score = 0.5; x = 0.25; _ }) ]);
  ] ->
      ()
  | _ -> failwith "FAILED probe_images lines decoded wrong");
  (match Wire.image_probes_of_string {|{"probes":{}}|} with
  | _ -> failwith "FAILED probe_images line without image decoded"
  | exception Wire.Decode_error _ -> ());
  print_endline "ok probe_images lines"

let () =
  let dir = contracts_dir () in
  let files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".json")
    |> List.sort compare
  in
  if List.length files < 20 then failwith "expected at least 20 golden files";
  List.iter (check_file dir (methods_by_id dir files)) files;
  (* Bad input names the field instead of crashing. *)
  (match
     Wire.message_of_string
       {|{"jsonrpc":"2.0","method":"frame","params":{"seq":"x"}}|}
   with
  | _ -> failwith "bad frame decoded"
  | exception Wire.Decode_error e ->
      Printf.printf "ok bad frame rejected: %s\n" e);
  (* Probe results are decoded by kind: another kind with the same fields is
     not color stats, and a result without a kind is an error. *)
  let frame_with result =
    Wire.message_of_string
      (Printf.sprintf
         {|{"jsonrpc":"2.0","method":"frame","params":{"seq":1,"load":0,"t_ms":0,"probes":{"p":%s}}}|}
         result)
  in
  (match
     frame_with {|{"kind":"core.other@1","mean":[1,2,3],"stddev":[1,2,3]}|}
   with
  | Wire.Notification
      (Wire.Frame { frame = { probes = [ ("p", Wire.Other _) ]; _ }; _ }) ->
      print_endline "ok other kind with color stats fields stays Other"
  | _ -> failwith "FAILED other kind decoded as color stats");
  (match frame_with {|{"mean":[1,2,3],"stddev":[1,2,3]}|} with
  | _ -> failwith "FAILED probe result without kind decoded"
  | exception Wire.Decode_error e ->
      Printf.printf "ok probe result without kind rejected: %s\n" e);
  check_template_upload dir;
  check_color_count dir;
  check_probe_constructors ();
  check_image_probes ()
