(* gamepilot runs [--runs-dir DIR]
   gamepilot runs --backfill [--apply] [--runs-dir DIR] (Run_backfill)

   The live runs on this machine, as the hub lists them
   (docs/design/Watch-Page.md): every daemon's watch registry entry
   ($GAMEPILOT_RUNS/.watch/<pid>.json) whose process is alive, with the
   checkpoint, mode and trial from the run's own /summary.json, its elapsed
   time, what it is doing (the current event and its time so far) and its
   page's URL. *)

module R = Wire.Watch_registry

let usage =
  "  gamepilot runs [--runs-dir DIR]\n\
  \  gamepilot runs --backfill [--apply] [--runs-dir DIR]\n"

(* Whether the process exists (EPERM: someone else's). Windows has no signal
   0 to send, so there every entry counts as alive. *)
let alive pid =
  match Unix.kill pid 0 with
  | () -> true
  | exception Unix.Unix_error (Unix.EPERM, _, _) -> true
  | exception Unix.Unix_error _ -> false
  | exception Invalid_argument _ -> true

let entry_of_file path =
  match R.of_json (Yojson.Safe.from_file path) with
  | entry -> Some entry
  | exception Yojson.Json_error _ -> None
  | exception Wire.Decode_error _ -> None
  | exception Sys_error _ -> None

(* The live entries in [dir], in pid order; none when it does not exist. *)
let live_entries dir =
  match Sys.readdir dir with
  | exception Sys_error _ -> []
  | names ->
      Array.to_list names
      |> List.filter (fun n -> Filename.check_suffix n ".json")
      |> List.filter_map (fun n -> entry_of_file (Filename.concat dir n))
      |> List.filter (fun (e : R.entry) -> alive e.pid)
      |> List.sort (fun (a : R.entry) b -> compare a.pid b.pid)

let timeout_s = 1.

let read_all fd =
  let buffer = Buffer.create 4096 and chunk = Bytes.create 4096 in
  let rec go () =
    match Unix.read fd chunk 0 (Bytes.length chunk) with
    | 0 -> Buffer.contents buffer
    | n ->
        Buffer.add_subbytes buffer chunk 0 n;
        go ()
  in
  go ()

(* The body of GET [path] on 127.0.0.1:[port]. *)
let http_get port path =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      Unix.setsockopt_float fd Unix.SO_RCVTIMEO timeout_s;
      Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
      let request = Printf.sprintf "GET %s HTTP/1.1\r\n\r\n" path in
      ignore (Unix.write_substring fd request 0 (String.length request) : int);
      let reply = read_all fd in
      match Daemon_process.find reply "\r\n\r\n" with
      | Some i -> Some (String.sub reply (i + 4) (String.length reply - i - 4))
      | None -> None)

let summary port =
  match http_get port "/summary.json" with
  | Some body -> Some (R.summary_of_json (Yojson.Safe.from_string body))
  | None -> None
  | exception Unix.Unix_error _ -> None
  | exception Yojson.Json_error _ -> None
  | exception Wire.Decode_error _ -> None

(* "4:05" or "1:02:09", as on the page. *)
let duration ms =
  let s = max 0 (ms / 1000) in
  let h = s / 3600 and m = s / 60 mod 60 in
  if h > 0 then Printf.sprintf "%d:%02d:%02d" h m (s mod 60)
  else Printf.sprintf "%d:%02d" m (s mod 60)

(* What the run is doing: its current (or failed) event and that event's
   time. *)
let state ~now_ms (plan : Wire.Watch.plan option) =
  let busy (e : Wire.Watch.plan_event) =
    e.state = Current || e.state = Failed
  in
  match Option.bind plan (fun p -> List.find_index busy p.events) with
  | None -> "-"
  | Some i ->
      let e = List.nth (Option.get plan).events i in
      let time =
        match Wire.Watch.event_ms ~now_ms:(Some now_ms) e with
        | Some ms -> " " ^ duration ms
        | None -> ""
      in
      Printf.sprintf "%s#%d %s%s"
        (if e.state = Failed then "failed at " else "")
        (i + 1) e.id time

let row ~now_ms (e : R.entry) (s : R.summary option) =
  let run = Option.bind s (fun s -> s.run) in
  let plan = Option.bind s (fun s -> s.plan) in
  let current =
    Option.bind run (fun (r : Wire.Watch_run.t) ->
        List.find_opt
          (fun (c : Wire.Watch_run.checkpoint) -> c.state = Current)
          r.checkpoints)
  in
  let checkpoint = match current with Some c -> c.id | None -> e.checkpoint in
  let mode, trial, started =
    match run with
    | Some r -> (r.mode, Printf.sprintf "%d/%d" r.trial r.trials, r.started_ms)
    | None -> ("-", "-", e.started_ms)
  in
  Printf.sprintf "%-10s %-12s %-6s %-8s %-40s %s" checkpoint mode trial
    (duration (now_ms - started))
    (state ~now_ms plan)
    (Watch_urls.url Watch_urls.local e.port)

let header =
  Printf.sprintf "%-10s %-12s %-6s %-8s %-40s %s" "CHECKPOINT" "MODE" "TRIAL"
    "ELAPSED" "STATE" "PAGE"

let show runs_dir =
  let entries = live_entries (Filename.concat runs_dir ".watch") in
  let now_ms = int_of_float (Unix.gettimeofday () *. 1000.) in
  if entries = [] then print_endline "no live runs"
  else (
    print_endline header;
    List.iter
      (fun (e : R.entry) -> print_endline (row ~now_ms e (summary e.port)))
      entries);
  Printf.printf "all runs: %s\n"
    (Watch_urls.url Watch_urls.local Watch_urls.hub_port);
  Ok 0

type flags = { runs_dir : string; backfill : bool; apply : bool }

let rec parse f = function
  | [] -> Ok f
  | "--runs-dir" :: dir :: rest -> parse { f with runs_dir = dir } rest
  | "--backfill" :: rest -> parse { f with backfill = true } rest
  | "--apply" :: rest -> parse { f with apply = true } rest
  | a :: _ -> Error ("unknown argument " ^ a)

(* --backfill: run.json for old run folders (Run_backfill). *)
let main args =
  let runs_dir = Checkpoints_flags.data_dir "GAMEPILOT_RUNS" "runs" in
  match parse { runs_dir; backfill = false; apply = false } args with
  | Error e -> Error e
  | Ok { apply = true; backfill = false; _ } -> Error "--apply needs --backfill"
  | Ok { backfill = true; runs_dir; apply } ->
      let live =
        live_entries (Filename.concat runs_dir ".watch")
        |> List.map (fun (e : R.entry) -> Filename.basename e.run_folder)
      in
      Run_backfill.main ~apply ~live runs_dir
  | Ok { runs_dir; _ } -> show runs_dir
