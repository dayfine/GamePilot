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

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "repo_io"
    [
      case "locate finds AGENTS.md from a nested dune test directory"
        locate_found "found";
      case "locate returns None for a missing path" locate_missing "missing";
      case "data_dir falls back to <home>/.local/share/gamepilot/<name>"
        data_dir_default "ok";
    ]
