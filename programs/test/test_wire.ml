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

(* Typed codecs for successful responses, by the method in the file name. *)
let result_round_trips =
  [
    ("hello", fun j -> Wire.(json_of_hello_result (hello_result_of_json j)));
    ( "load_state",
      fun j -> Wire.(json_of_load_state_result (load_state_result_of_json j)) );
    ( "subscribe",
      fun j -> Wire.(json_of_subscribe_result (subscribe_result_of_json j)) );
    ("submit", fun j -> Wire.(json_of_submit_result (submit_result_of_json j)));
    ("cancel", fun j -> Wire.(json_of_cancel_result (cancel_result_of_json j)));
  ]

(* "02-hello.response.json" -> "hello" *)
let method_of_file file =
  let base = Filename.chop_extension (Filename.chop_extension file) in
  String.sub base 3 (String.length base - 3)

let check_file dir file =
  let text =
    In_channel.with_open_bin (Filename.concat dir file) In_channel.input_all
  in
  let golden = Yojson.Safe.from_string text in
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
  | Wire.Response { outcome = Ok result; _ } -> (
      let m = method_of_file file in
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
  List.iter (check_file dir) files;
  (* Bad input names the field instead of crashing. *)
  match
    Wire.message_of_string
      {|{"jsonrpc":"2.0","method":"frame","params":{"seq":"x"}}|}
  with
  | _ -> failwith "bad frame decoded"
  | exception Wire.Decode_error e ->
      Printf.printf "ok bad frame rejected: %s\n" e
