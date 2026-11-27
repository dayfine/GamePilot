exception Divergence of string

(* Each entry keeps its 1-based line number in the log file. *)
type log = (int * Wire.log_line) array

let json_of_string s =
  try Yojson.Safe.from_string s
  with Yojson.Json_error e -> raise (Wire.Decode_error e)

let parse_line (n, s) =
  match Wire.log_line_of_json (json_of_string s) with
  | line -> (n, line)
  | exception Wire.Decode_error e ->
      raise (Wire.Decode_error (Printf.sprintf "wire log line %d: %s" n e))

(* The program's connection: the one of the log's first client line. Other
   clients' lines (a [gamepilot ctl] reading the screen) are not the
   program's. *)
let program_lines (lines : (int * Wire.log_line) list) =
  match List.find_opt (fun (_, (l : Wire.log_line)) -> l.dir = In) lines with
  | None -> lines
  | Some (_, first) ->
      List.filter
        (fun (_, (l : Wire.log_line)) -> l.dir = Daemon || l.conn = first.conn)
        lines

let log_of_lines lines =
  List.mapi (fun i s -> (i + 1, String.trim s)) lines
  |> List.filter (fun (_, s) -> s <> "")
  |> List.map parse_line |> program_lines |> Array.of_list

let log_of_file path =
  log_of_lines
    (String.split_on_char '\n'
       (In_channel.with_open_bin path In_channel.input_all))

let diverge fmt = Printf.ksprintf (fun s -> raise (Divergence s)) fmt

let describe_stick name = function
  | None -> ""
  | Some (stick : Wire.stick) ->
      let x, y = (stick :> float * float) in
      Printf.sprintf " %s %g,%g" name x y

let describe_command = function
  | Wire.Press { buttons; left_stick; right_stick; hold_ms; cooldown_ms } ->
      Printf.sprintf "press %s%s%s hold %d cooldown %d"
        (String.concat "+" (List.map Wire.string_of_button buttons))
        (describe_stick "left" left_stick)
        (describe_stick "right" right_stick)
        hold_ms cooldown_ms
  | Wire.Wait { wait_ms } -> Printf.sprintf "wait %d" wait_ms

let describe_commands commands =
  "[" ^ String.concat "; " (List.map describe_command commands) ^ "]"

let describe_call_args = function
  | Wire.Submit { commands; start_at_t_ms; _ } ->
      let at =
        Option.fold ~none:""
          ~some:(fun t -> Printf.sprintf " at %g" t)
          start_at_t_ms
      in
      " " ^ describe_commands commands ^ at
  | Wire.Unsubscribe ids -> " [" ^ String.concat ", " ids ^ "]"
  | _ -> ""

let describe = function
  | Wire.Request { id; call } ->
      Printf.sprintf "%s (id %d)%s" (Wire.method_name call) id
        (describe_call_args call)
  | m -> Wire.string_of_message m

(* The first field in which two requests of the same method differ. *)
let differing_field (e : Wire.request) (a : Wire.request) =
  match (e.call, a.call) with
  | Wire.Subscribe ep, Wire.Subscribe ap when ep <> ap -> Some "probes"
  | Wire.Unsubscribe ei, Wire.Unsubscribe ai when ei <> ai -> Some "ids"
  | Wire.Upload_template ep, Wire.Upload_template ap when ep.png <> ap.png ->
      Some "template"
  | Wire.Submit ec, Wire.Submit ac when ec.commands <> ac.commands ->
      Some "commands"
  | Wire.Submit ec, Wire.Submit ac when ec.start_at_t_ms <> ac.start_at_t_ms ->
      Some "start_at_t_ms"
  | Wire.Submit ec, Wire.Submit ac when ec.batch_id <> ac.batch_id ->
      Some "batch id"
  | _ -> if e.id <> a.id then Some "request id" else None

(* [expected] is the log's client message at line [n], [actual] the program's. *)
let check n ~expected ~actual =
  let mismatch what =
    diverge "wire log line %d: %s differs: program sent %s, log has %s" n what
      (describe actual) (describe expected)
  in
  match (expected, actual) with
  | Wire.Request e, Wire.Request a ->
      if Wire.method_name e.call <> Wire.method_name a.call then
        mismatch "method";
      Option.iter mismatch (differing_field e a)
  | _ -> mismatch "message"

let is_dir dir ((_, l) : int * Wire.log_line) = l.dir = dir

let find_from (log : log) i p =
  let rec go i =
    if i >= Array.length log then None
    else if p log.(i) then Some i
    else go (i + 1)
  in
  go i

(* Where the replay is in the log.
   [next_in]: index of the next client message the program must send.
   [next_out]: index of the next log entry to scan for daemon output.
   [ran_out]: set when the program waits for daemon output but the recorded
   client spoke first: the live run's wait ended there. The first time, the
   wall clock jumps to infinity so a pending [await] times out (the reader did
   not hold on the recorded frames); waiting again is a divergence.
   [timed_out]: set once a wait timed out at a recorded point; from then on the
   program follows its own failure path, so it need not send the rest. *)
type cursor = {
  log : log;
  mutable next_in : int;
  mutable next_out : int;
  mutable ran_out : bool;
  mutable timed_out : bool;
}

let next_client_message r = find_from r.log r.next_in (is_dir Wire.In)

(* The program's watch notifications are not in the wire log (the daemon keeps
   them out), so the replay drops them too. *)
let rec send r actual =
  match actual with
  | Wire.Notification
      ( Wire.Watch_plan _ | Wire.Watch_log _ | Wire.Watch_run _
      | Wire.Watch_counters _ ) ->
      ()
  | _ -> send_logged r actual

and send_logged r actual =
  r.ran_out <- false;
  match next_client_message r with
  | None ->
      diverge "program sent %s after the log's last client message"
        (describe actual)
  | Some i ->
      let n, expected = r.log.(i) in
      check n ~expected:expected.msg ~actual;
      r.next_in <- i + 1

(* The program waits for daemon output, but the recorded client sent the
   message at index [j] first. *)
let client_spoke_first r j =
  if r.ran_out then
    let n, l = r.log.(j) in
    diverge
      "wire log line %d: program waits for daemon output, but the recorded \
       client sent %s first"
      n (describe l.msg)
  else (
    r.ran_out <- true;
    r.timed_out <- true;
    Session.Idle)

(* Delivers the daemon output at index [i], unless the client spoke first. *)
let deliver r i =
  match next_client_message r with
  | Some j when j < i -> client_spoke_first r j
  | _ ->
      r.next_out <- i + 1;
      Session.Message (snd r.log.(i)).msg

let recv r =
  match find_from r.log r.next_out (is_dir Wire.Out) with
  | None -> Session.Closed "end of wire log"
  | Some i -> deliver r i

let transport r : Session.transport =
  {
    send = send r;
    recv = (fun () -> recv r);
    wall_ms = (fun () -> if r.ran_out then infinity else 0.);
  }

let run_with_backend log f =
  let r =
    { log; next_in = 0; next_out = 0; ran_out = false; timed_out = false }
  in
  let result = Session.run_with_backend (transport r) f in
  (match next_client_message r with
  | Some i when not r.timed_out ->
      let n, l = log.(i) in
      diverge "wire log line %d: program ended without sending %s" n
        (describe l.msg)
  | Some _ | None -> ());
  result

let run log f = run_with_backend log (fun (_ : Wire.backend) -> f ())
