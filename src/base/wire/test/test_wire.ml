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
    ( "subscribe",
      fun j -> Wire.(json_of_subscribe_result (subscribe_result_of_json j)) );
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

let () =
  let dir = contracts_dir () in
  let files =
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun f -> Filename.check_suffix f ".json")
    |> List.sort compare
  in
  if List.length files < 14 then failwith "expected at least 14 golden files";
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
  match frame_with {|{"mean":[1,2,3],"stddev":[1,2,3]}|} with
  | _ -> failwith "FAILED probe result without kind decoded"
  | exception Wire.Decode_error e ->
      Printf.printf "ok probe result without kind rejected: %s\n" e
