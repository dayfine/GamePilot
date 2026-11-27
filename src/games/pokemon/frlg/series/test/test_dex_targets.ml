(* Dex_targets: option parsing, evolution-line target counts, species
   filtering, and v1/v2 dex_progress.json roundtrip. Uses temporary files for
   progress JSON tests. *)

open Frlg_series

let dex_decl : Run_options.declared list =
  [
    {
      key = "target";
      value =
        One_of
          [
            "everything";
            "missing-on-dex";
            "version-exclusive";
            "version-exclusive-uncaught";
            "specific-list";
          ];
      presence = Default "everything";
      doc = "";
    };
    { key = "species"; value = Text; presence = Optional; doc = "" };
  ]

let opts pairs = Result.get_ok (Run_options.check dex_decl pairs)
let failures = ref 0
let ran = ref 0

let check ~show name expected actual =
  incr ran;
  if expected <> actual then (
    incr failures;
    Printf.eprintf "FAIL %s:\n  expected: %s\n  actual:   %s\n%!" name
      (show expected) (show actual))

let show_bool = string_of_bool
let show_int = string_of_int

let show_mode = function
  | None -> "None"
  | Some Dex_targets.Everything -> "Some Everything"
  | Some Missing_on_dex -> "Some Missing_on_dex"
  | Some Version_exclusive -> "Some Version_exclusive"
  | Some Version_exclusive_uncaught -> "Some Version_exclusive_uncaught"
  | Some (Specific_list xs) ->
      "Some (Specific_list [" ^ String.concat "; " xs ^ "])"

let show_result show_ok = function
  | Ok v -> "Ok (" ^ show_ok v ^ ")"
  | Error e -> "Error " ^ Printf.sprintf "%S" e

let show_counts xs =
  "["
  ^ String.concat "; "
      (List.map (fun (k, n) -> Printf.sprintf "(%s, %d)" k n) xs)
  ^ "]"

let show_strings xs = "[" ^ String.concat "; " xs ^ "]"

let with_temp_path f =
  let dir = Filename.temp_file "dex_targets_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "dex_progress.json" in
  let cleanup () =
    if Sys.file_exists path then Sys.remove path;
    if Sys.file_exists dir then Unix.rmdir dir
  in
  Fun.protect ~finally:cleanup (fun () -> f dir path)

let test_options () =
  let check_opt name pairs expected =
    check ~show:(show_result show_mode) name expected
      (Dex_targets.of_options (opts pairs))
  in
  check ~show:(show_result show_mode) "no target declared -> None" (Ok None)
    (Dex_targets.of_options Run_options.none);
  check_opt "default target is everything" [] (Ok (Some Everything));
  check_opt "missing-on-dex"
    [ ("target", "missing-on-dex") ]
    (Ok (Some Missing_on_dex));
  check_opt "version-exclusive"
    [ ("target", "version-exclusive") ]
    (Ok (Some Version_exclusive));
  check_opt "specific-list parses species"
    [ ("target", "specific-list"); ("species", "Ekans, voltorb") ]
    (Ok (Some (Specific_list [ "ekans"; "voltorb" ])));
  check_opt "specific-list without species fails"
    [ ("target", "specific-list") ]
    (Error "--options target=specific-list requires --options species=SLUG,...");
  check_opt "species with everything fails"
    [ ("target", "everything"); ("species", "ekans") ]
    (Error
       "--options species=... is only used with --options target=specific-list")

let test_counts_and_filtering () =
  check ~show:show_int "required_count ekans" 2
    (Dex_targets.required_count "ekans");
  check ~show:show_int "required_count oddish" 3
    (Dex_targets.required_count "oddish");
  check ~show:show_int "required_count electabuzz" 1
    (Dex_targets.required_count "electabuzz");
  check ~show:show_int "required_count non-exclusive defaults to 1" 1
    (Dex_targets.required_count "voltorb");
  check ~show:show_int "remaining ekans with 1 caught" 1
    (Dex_targets.remaining ~counts:[ ("ekans", 1) ] "ekans");
  check ~show:show_int "remaining ekans with 2 caught" 0
    (Dex_targets.remaining ~counts:[ ("ekans", 2) ] "ekans");
  check ~show:show_int "remaining with explicit target override" 2
    (Dex_targets.remaining ~counts:[ ("voltorb", 1) ] ~target:3 "voltorb");
  let check_run name mode counts species expected =
    check ~show:show_bool name expected
      (Dex_targets.should_run ~mode ~counts species)
  in
  check_run "non-catch checkpoint always runs" (Specific_list [ "ekans" ])
    [ ("ekans", 2) ]
    None true;
  check_run "everything skips species at target count" Everything
    [ ("voltorb", 1) ]
    (Some "voltorb") false;
  check_run "everything keeps species below evolution-line target" Everything
    [ ("ekans", 1) ]
    (Some "ekans") true;
  check_run "everything skips species once evolution-line target met" Everything
    [ ("ekans", 2) ]
    (Some "ekans") false;
  check_run "version-exclusive keeps ekans even when quota met"
    Version_exclusive
    [ ("ekans", 2) ]
    (Some "ekans") true;
  check_run "version-exclusive skips voltorb" Version_exclusive []
    (Some "voltorb") false;
  check_run "version-exclusive-uncaught keeps ekans at 1/2"
    Version_exclusive_uncaught
    [ ("ekans", 1) ]
    (Some "ekans") true;
  check_run "version-exclusive-uncaught skips ekans at 2/2"
    Version_exclusive_uncaught
    [ ("ekans", 2) ]
    (Some "ekans") false;
  check_run "specific-list matches named species" (Specific_list [ "drowzee" ])
    [] (Some "drowzee") true;
  check_run "specific-list skips unnamed species" (Specific_list [ "drowzee" ])
    [] (Some "ekans") false

let test_v2_roundtrip () =
  with_temp_path (fun _dir path ->
      check ~show:(show_result show_counts) "missing file yields empty counts"
        (Ok [])
        (Dex_targets.load_counts ~path ());
      check
        ~show:(show_result (fun () -> "()"))
        "record 1st ekans" (Ok ())
        (Dex_targets.record_caught ~path "Ekans");
      check
        ~show:(show_result (fun () -> "()"))
        "record 2nd ekans" (Ok ())
        (Dex_targets.record_caught ~path "ekans");
      check
        ~show:(show_result (fun () -> "()"))
        "record voltorb" (Ok ())
        (Dex_targets.record_caught ~path "voltorb");
      check ~show:(show_result show_counts) "v2 counts roundtrip"
        (Ok [ ("ekans", 2); ("voltorb", 1) ])
        (Dex_targets.load_counts ~path ());
      check ~show:(show_result show_strings) "load_caught returns keys"
        (Ok [ "ekans"; "voltorb" ])
        (Dex_targets.load_caught ~path ());
      let raw = Result.get_ok (Repo_io.Json_file.read path) in
      let expected_json =
        `Assoc
          [
            ("version", `Int 2);
            ("counts", `Assoc [ ("ekans", `Int 2); ("voltorb", `Int 1) ]);
          ]
      in
      check ~show:Yojson.Safe.to_string "writes version 2 JSON" expected_json
        raw)

let test_v1_compat () =
  with_temp_path (fun dir path ->
      Unix.mkdir dir 0o755;
      let v1 =
        `Assoc [ ("caught", `List [ `String "Ekans"; `String "voltorb" ]) ]
      in
      ignore (Result.get_ok (Repo_io.Json_file.write path v1));
      check ~show:(show_result show_counts) "reads v1 caught list as count 1"
        (Ok [ ("ekans", 1); ("voltorb", 1) ])
        (Dex_targets.load_counts ~path ());
      check
        ~show:(show_result (fun () -> "()"))
        "incrementing v1 upgrades to v2" (Ok ())
        (Dex_targets.record_caught ~path "ekans");
      check ~show:(show_result show_counts) "upgraded v2 counts"
        (Ok [ ("ekans", 2); ("voltorb", 1) ])
        (Dex_targets.load_counts ~path ()))

let () =
  test_options ();
  test_counts_and_filtering ();
  test_v2_roundtrip ();
  test_v1_compat ();
  if !failures = 0 then Printf.printf "dex_targets: %d ok\n%!" !ran
  else (
    Printf.eprintf "dex_targets: %d of %d failed\n%!" !failures !ran;
    exit 1)
