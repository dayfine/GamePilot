(* The sticks of a press (protocol v1.12): the golden run decodes to the
   commands a program builds, a press without sticks stays a plain press, and
   a tilt outside -1..1 is an error. *)

let protocol_file name =
  let rec up dir =
    let candidate = Filename.concat dir (Filename.concat "protocol/v1" name) in
    if Sys.file_exists candidate then candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then failwith ("protocol/v1/" ^ name ^ " not found")
      else up parent
  in
  up (Sys.getcwd ())

let golden_call name =
  match Wire.message_of_json (Yojson.Safe.from_file (protocol_file name)) with
  | Wire.Request { call; _ } -> call
  | _ -> failwith (name ^ ": expected a request")

let stick x y = match Wire.stick x y with Ok s -> s | Error e -> failwith e

let check_golden_run () =
  let expected =
    [
      Wire.Press_with_sticks
        {
          buttons = [ B ];
          left_stick = Some (stick 0. 1.);
          right_stick = None;
          hold_ms = 1200;
          cooldown_ms = 0;
        };
      Wire.Press_with_sticks
        {
          buttons = [ B ];
          left_stick = Some (stick 0.5 0.866);
          right_stick = None;
          hold_ms = 400;
          cooldown_ms = 0;
        };
      Wire.Press_with_sticks
        {
          buttons = [];
          left_stick = None;
          right_stick = Some (stick (-1.) 0.);
          hold_ms = 300;
          cooldown_ms = 100;
        };
    ]
  in
  (match golden_call "44-submit.sticks.request.json" with
  | Wire.Submit { batch_id = "run"; commands } when commands = expected -> ()
  | _ -> failwith "FAILED the golden run decodes to other commands");
  (match golden_call "08-submit.request.json" with
  | Wire.Submit { commands = Wire.Press _ :: _; _ } -> ()
  | _ -> failwith "FAILED a press without sticks is not a plain press");
  print_endline "ok golden run"

let submit_with command =
  Printf.sprintf
    {|{"jsonrpc":"2.0","id":1,"method":"submit","params":{"batch_id":"b","commands":[%s]}}|}
    command

let check_rejected () =
  List.iter
    (fun command ->
      match Wire.message_of_string (submit_with command) with
      | _ -> failwith ("FAILED decoded: " ^ command)
      | exception Wire.Decode_error e -> Printf.printf "ok rejected: %s\n" e)
    [
      {|{"press":[],"left_stick":[1.5,0],"hold_ms":1,"cooldown_ms":0}|};
      {|{"press":[],"right_stick":[0,-1.01],"hold_ms":1,"cooldown_ms":0}|};
      {|{"press":[],"left_stick":[0],"hold_ms":1,"cooldown_ms":0}|};
      {|{"press":[],"left_stick":[0,0,0],"hold_ms":1,"cooldown_ms":0}|};
      {|{"press":[],"left_stick":["up",0],"hold_ms":1,"cooldown_ms":0}|};
    ];
  List.iter
    (fun (x, y) ->
      match Wire.stick x y with
      | Ok _ -> failwith (Printf.sprintf "FAILED stick %g %g accepted" x y)
      | Error _ -> ())
    [ (1.0001, 0.); (0., -2.); (Float.nan, 0.); (0., Float.infinity) ];
  print_endline "ok out of range sticks are errors"

let () =
  check_golden_run ();
  check_rejected ()
