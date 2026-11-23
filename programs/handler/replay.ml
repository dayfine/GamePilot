exception Divergence of string

(* Each entry keeps its 1-based line number in the log file. *)
type log = (int * Wire.log_line) array

let log_of_lines lines =
  List.mapi (fun i s -> (i + 1, String.trim s)) lines
  |> List.filter (fun (_, s) -> s <> "")
  |> List.map (fun (n, s) ->
         let line =
           try
             Wire.log_line_of_json
               (try Yojson.Safe.from_string s
                with Yojson.Json_error e -> raise (Wire.Decode_error e))
           with Wire.Decode_error e ->
             raise
               (Wire.Decode_error (Printf.sprintf "wire log line %d: %s" n e))
         in
         (n, line))
  |> Array.of_list

let log_of_file path =
  log_of_lines
    (String.split_on_char '\n'
       (In_channel.with_open_bin path In_channel.input_all))

let diverge fmt = Printf.ksprintf (fun s -> raise (Divergence s)) fmt

let describe_commands commands =
  let one = function
    | Wire.Press { buttons; hold_ms; cooldown_ms } ->
        Printf.sprintf "press %s hold %d cooldown %d"
          (String.concat "+" (List.map Wire.string_of_button buttons))
          hold_ms cooldown_ms
    | Wire.Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms
  in
  "[" ^ String.concat "; " (List.map one commands) ^ "]"

let describe = function
  | Wire.Request { id; call } ->
      Printf.sprintf "%s (id %d)%s" (Wire.method_name call) id
        (match call with
        | Wire.Submit { commands; _ } -> " " ^ describe_commands commands
        | _ -> "")
  | m -> Wire.string_of_message m

(* [expected] is the log's client message at line [n], [actual] the program's. *)
let check n ~expected ~actual =
  let mismatch what =
    diverge "wire log line %d: %s differs: program sent %s, log has %s" n what
      (describe actual) (describe expected)
  in
  match (expected, actual) with
  | Wire.Request e, Wire.Request a -> (
      if Wire.method_name e.call <> Wire.method_name a.call then
        mismatch "method";
      match (e.call, a.call) with
      | Wire.Subscribe ep, Wire.Subscribe ap when ep <> ap -> mismatch "probes"
      | Wire.Submit ec, Wire.Submit ac when ec.commands <> ac.commands ->
          mismatch "commands"
      | Wire.Submit ec, Wire.Submit ac when ec.batch_id <> ac.batch_id ->
          mismatch "batch id"
      | _ -> if e.id <> a.id then mismatch "request id")
  | _ -> mismatch "message"

let is_dir dir ((_, l) : int * Wire.log_line) = l.dir = dir

let find_from (log : log) i p =
  let rec go i =
    if i >= Array.length log then None
    else if p log.(i) then Some i
    else go (i + 1)
  in
  go i

let transport (log : log) : Session.transport =
  (* Index of the next client message the program must send, and of the next
     log entry to scan for daemon output. *)
  let next_in = ref 0 and next_out = ref 0 in
  let send actual =
    match find_from log !next_in (is_dir Wire.In) with
    | None ->
        diverge "program sent %s after the log's last client message"
          (describe actual)
    | Some i ->
        let n, expected = log.(i) in
        check n ~expected:expected.msg ~actual;
        next_in := i + 1
  in
  let recv () =
    match find_from log !next_out (is_dir Wire.Out) with
    | None -> Session.Closed "end of wire log"
    | Some i -> (
        match find_from log !next_in (is_dir Wire.In) with
        | Some j when j < i ->
            let n, l = log.(j) in
            diverge
              "wire log line %d: program waits for daemon output, but the \
               recorded client sent %s first"
              n (describe l.msg)
        | _ ->
            next_out := i + 1;
            Session.Message (snd log.(i)).msg)
  in
  { send; recv; wall_ms = (fun () -> 0.) }

let run log f = Session.run (transport log) f
