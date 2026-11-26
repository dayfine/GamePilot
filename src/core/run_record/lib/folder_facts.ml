(* What an old run folder says of its run without a run.json, for
   gamepilot runs --backfill; the hub's own fallbacks are the same
   (daemon/src/run_history.h). *)

let read_text path =
  match In_channel.with_open_bin path In_channel.input_all with
  | text -> Some text
  | exception Sys_error _ -> None

let ms_per_s = 1000.

let mtime_ms path =
  match Unix.stat path with
  | st -> Some (int_of_float (st.st_mtime *. ms_per_s))
  | exception Unix.Unix_error _ -> None

let json_field path key =
  match Option.map Yojson.Safe.from_string (read_text path) with
  | Some (`Assoc fields) -> List.assoc_opt key fields
  | _ -> None
  | exception Yojson.Json_error _ -> None

let number = function
  | Some (`Int n) -> Some (float_of_int n)
  | Some (`Float f) -> Some f
  | _ -> None

(* A wire log line's t_ms. *)
let t_ms line =
  match Yojson.Safe.from_string line with
  | `Assoc fields -> number (List.assoc_opt "t_ms" fields)
  | _ -> None
  | exception Yojson.Json_error _ -> None

(* The t_ms of the wire log's first and last lines; the end read from its
   last 64 KiB, so a long log costs little. *)
let tail_bytes = 65536
let first_line ic = try t_ms (input_line ic) with End_of_file -> None

let last_line ic =
  let size = in_channel_length ic in
  seek_in ic (max 0 (size - tail_bytes));
  let tail = really_input_string ic (size - pos_in ic) in
  let lines = String.split_on_char '\n' (String.trim tail) in
  Option.bind (List.nth_opt (List.rev lines) 0) t_ms

let span ic =
  match (first_line ic, last_line ic) with
  | Some a, Some b -> Some (a, b)
  | _ -> None

let wire_span path =
  match open_in_bin path with
  | exception Sys_error _ -> None
  | ic -> Fun.protect ~finally:(fun () -> close_in ic) (fun () -> span ic)

let backend_of_output text =
  if Strings.Contains.substring text "daemon: mgba" then "mgba"
  else if
    String.starts_with ~prefix:"board:" text
    || Strings.Contains.substring text "daemon: switch"
    || Strings.Contains.substring text "daemon: board"
  then "switch"
  else ""

let head_bytes = 512

let output_backend dir =
  match read_text (Filename.concat dir "daemon.out") with
  | Some text ->
      backend_of_output
        (String.sub text 0 (min head_bytes (String.length text)))
  | None -> ""

let backend dir =
  match json_field (Filename.concat dir "daemon.json") "backend" with
  | Some (`String b) when b <> "" -> b
  | _ -> output_backend dir

(* Start and end, Unix ms: daemon.json's clock zero and the wire log's last
   line; else the wire log's span back from its last write; else the
   folder's mtime and no end. *)
let times dir =
  let wire = Filename.concat dir "wire.jsonl" in
  let zero =
    number (json_field (Filename.concat dir "daemon.json") "clock_zero_unix_ms")
  in
  let span = wire_span wire in
  match (zero, span, mtime_ms wire) with
  | Some z, Some (_, last), _ ->
      (int_of_float z, Some (int_of_float (z +. last)))
  | Some z, None, _ -> (int_of_float z, None)
  | None, Some (first, last), Some written ->
      (written - int_of_float (last -. first), Some written)
  | None, _, _ -> (Option.value (mtime_ms dir) ~default:0, None)

let of_folder dir =
  let started, ended = times dir in
  [ ("backend", `String (backend dir)); ("started_ms", `Int started) ]
  @ Option.fold ~none:[] ~some:(fun e -> [ ("ended_ms", `Int e) ]) ended

let preflight_verdict checkpoint lines =
  let prefix = "[Preflight] " ^ checkpoint ^ ": " in
  let verdict =
    List.find_map
      (fun line ->
        if String.starts_with ~prefix line then
          let n = String.length prefix in
          Some (String.sub line n (String.length line - n))
        else None)
      (List.rev lines)
  in
  let s v = `String v in
  match verdict with
  | None -> []
  | Some "the save holds what it needs" -> [ ("result", s "pass") ]
  | Some why ->
      [ ("result", s "fail"); ("at", s "preflight"); ("reason", s why) ]
