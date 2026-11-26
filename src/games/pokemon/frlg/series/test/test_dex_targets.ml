(* Dex_targets: option parsing, species filtering, and local progress JSON. *)

open Frlg_series

let case name input expectation = { Table_test.name; input; expectation }

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

let mode_text = function
  | None -> "none"
  | Some Dex_targets.Everything -> "everything"
  | Some Missing_on_dex -> "missing-on-dex"
  | Some Version_exclusive -> "version-exclusive"
  | Some Version_exclusive_uncaught -> "version-exclusive-uncaught"
  | Some (Specific_list xs) -> "specific:" ^ String.concat "," xs

let parse pairs () =
  match Dex_targets.of_options (opts pairs) with
  | Ok m -> mode_text m
  | Error e -> "error: " ^ e

let run_check mode caught species () =
  string_of_bool (Dex_targets.should_run ~mode ~caught species)

let roundtrip () =
  let dir = Filename.temp_file "dex_targets_" "" in
  Sys.remove dir;
  let path = Filename.concat dir "dex_progress.json" in
  let r =
    match Dex_targets.load_caught ~path () with
    | Error e -> "load1 error: " ^ e
    | Ok [] -> (
        match Dex_targets.record_caught ~path "Ekans" with
        | Error e -> "rec1 error: " ^ e
        | Ok () -> (
            match Dex_targets.record_caught ~path "voltorb" with
            | Error e -> "rec2 error: " ^ e
            | Ok () -> (
                match Dex_targets.load_caught ~path () with
                | Error e -> "load2 error: " ^ e
                | Ok xs -> String.concat "," xs)))
    | Ok _ -> "unexpected non-empty"
  in
  if Sys.file_exists path then Sys.remove path;
  if Sys.file_exists dir then Unix.rmdir dir;
  r

let cases =
  [
    case "no target declared -> None"
      (fun () ->
        match Dex_targets.of_options Run_options.none with
        | Ok m -> mode_text m
        | Error e -> "error: " ^ e)
      "none";
    case "default target is everything" (parse []) "everything";
    case "missing-on-dex"
      (parse [ ("target", "missing-on-dex") ])
      "missing-on-dex";
    case "version-exclusive"
      (parse [ ("target", "version-exclusive") ])
      "version-exclusive";
    case "specific-list parses species"
      (parse [ ("target", "specific-list"); ("species", "Ekans, voltorb") ])
      "specific:ekans,voltorb";
    case "specific-list without species fails"
      (parse [ ("target", "specific-list") ])
      "error: --options target=specific-list requires --options \
       species=SLUG,...";
    case "species with everything fails"
      (parse [ ("target", "everything"); ("species", "ekans") ])
      "error: --options species=... is only used with --options \
       target=specific-list";
    case "non-catch checkpoint always runs"
      (run_check (Specific_list [ "ekans" ]) [ "ekans" ] None)
      "true";
    case "everything skips caught species"
      (run_check Everything [ "voltorb" ] (Some "voltorb"))
      "false";
    case "everything runs uncaught species"
      (run_check Everything [ "voltorb" ] (Some "ekans"))
      "true";
    case "version-exclusive keeps ekans"
      (run_check Version_exclusive [ "ekans" ] (Some "ekans"))
      "true";
    case "version-exclusive skips voltorb"
      (run_check Version_exclusive [] (Some "voltorb"))
      "false";
    case "version-exclusive-uncaught skips caught ekans"
      (run_check Version_exclusive_uncaught [ "ekans" ] (Some "ekans"))
      "false";
    case "specific-list matches named species"
      (run_check (Specific_list [ "drowzee" ]) [] (Some "drowzee"))
      "true";
    case "specific-list skips unnamed species"
      (run_check (Specific_list [ "drowzee" ]) [] (Some "ekans"))
      "false";
    case "local dex_progress.json roundtrip" roundtrip "ekans,voltorb";
  ]

let () = Table_test.run "dex_targets" cases
