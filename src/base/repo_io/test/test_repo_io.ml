(* Repo_io: Repo_files.locate and Repo_files.data_dir tested against the repo
   layout and explicit environment variables (no external mocks). *)

open Repo_io

let locate_found () =
  match Repo_files.locate "AGENTS.md" with
  | Some _ -> "found"
  | None -> "missing"

let locate_missing () =
  match Repo_files.locate "definitely-does-not-exist-gamepilot.xyz" with
  | Some _ -> "found"
  | None -> "missing"

let data_dir_default () =
  let dir = Repo_files.data_dir "GAMEPILOT_TEST_UNSET_VAR_XYZ" "runs" in
  let suffix =
    List.fold_left Filename.concat ".local" [ "share"; "gamepilot"; "runs" ]
  in
  let len_d = String.length dir and len_s = String.length suffix in
  if len_d >= len_s && String.sub dir (len_d - len_s) len_s = suffix then "ok"
  else "unexpected: " ^ dir

let locate_in_found () =
  let dir = Filename.temp_file "repo_io_share_" "" in
  Sys.remove dir;
  Sys.mkdir dir 0o755;
  let rel = "sample.txt" in
  let full = Filename.concat dir rel in
  let oc = open_out full in
  output_string oc "ok";
  close_out oc;
  let got =
    match
      Repo_files.locate_in ~roots:[ "/nonexistent-gamepilot-root"; dir ] rel
    with
    | Some p when p = full -> "found"
    | Some p -> "wrong: " ^ p
    | None -> "missing"
  in
  Sys.remove full;
  Sys.rmdir dir;
  got

let default_daemon_dev () =
  let d = Repo_files.default_daemon () in
  if d = "daemon/build/gamepilot_daemon" || Sys.file_exists d then "ok"
  else "unexpected: " ^ d

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "repo_io"
    [
      case "locate finds AGENTS.md from a nested dune test directory"
        locate_found "found";
      case "locate returns None for a missing path" locate_missing "missing";
      case "locate_in finds a file in a packaged share root" locate_in_found
        "found";
      case "default_daemon returns dev default or existing packaged binary"
        default_daemon_dev "ok";
      case "data_dir falls back to <home>/.local/share/gamepilot/<name>"
        data_dir_default "ok";
    ]
