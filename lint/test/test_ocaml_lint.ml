(* Each case pins a bug class the checks exist to catch, with a fixture that
   must fail and, where the rule has a known false-positive risk, one that
   must pass. *)

open Ocaml_lint

let config = { Config.default with roots = [ "." ] }

let parse text =
  match Parsed_source.parse ~path:"lib/m.ml" text with
  | Ok src -> src
  | Error f -> failwith (Finding.to_string f)

let lines n make = String.concat "\n" (List.init n make) ^ "\n"
let checks findings = List.map (fun (f : Finding.t) -> f.check) findings
let failures = ref 0

let case name ~expect actual =
  if actual = expect then Printf.printf "ok %s\n" name
  else (
    incr failures;
    Printf.printf "FAIL %s: expected [%s], got [%s]\n" name
      (String.concat "; " expect)
      (String.concat "; " actual))

(* --- function length --- *)

let long_body = lines 55 (fun i -> Printf.sprintf "  ignore %d;" i) ^ "  x\n"

let () =
  case "function_length: a long function inside a submodule is caught"
    ~expect:[ "function_length" ]
    (checks
       (Function_length.check config
          (parse ("module M = struct\nlet f x =\n" ^ long_body ^ "end\n"))));
  case "function_length: a long data table is not a function" ~expect:[]
    (checks
       (Function_length.check config
          (parse
             ("let table = [\n"
             ^ lines 60 (fun i -> Printf.sprintf "  %d;" i)
             ^ "]\n"))))

(* --- nesting --- *)

let () =
  case "nesting: else -> let -> if is a nested else" ~expect:[ "nesting" ]
    (checks
       (Nesting.check config
          (parse
             "let f a b =\n\
             \  if a then 0\n\
             \  else\n\
             \    let c = b + 1 in\n\
             \    if c > b then 1 else 2\n")));
  case "nesting: an else-if chain is flat" ~expect:[]
    (checks
       (Nesting.check config
          (parse "let f a b =\n  if a then 0\n  else if b then 1\n  else 2\n")))

(* --- magic numbers --- *)

let () =
  case "magic_numbers: a bare literal in arithmetic is caught"
    ~expect:[ "magic_numbers"; "magic_numbers" ]
    (checks
       (Magic_numbers.check
          (parse "let f x = (x * 86400) + int_of_float 0.75\n")));
  case
    "magic_numbers: named constants, field defaults, optional defaults and \
     patterns pass"
    ~expect:[]
    (checks
       (Magic_numbers.check
          (parse
             "let seconds_per_day = 86400\n\
              let default = { timeout_ms = 3000; ratio = 0.75 }\n\
              let f ?(retries = 10) x =\n\
             \  match x with 42 -> retries | _ -> seconds_per_day\n")))

(* --- complexity --- *)

let branches =
  lines 11 (fun i -> Printf.sprintf "  if x = %d then print_int %d;" i i)

let () =
  let findings =
    Complexity.check config (parse ("let f x =\n" ^ branches ^ "  ()\n"))
  in
  case "complexity: a branchy function is advisory, never an error"
    ~expect:[ "complexity advisory" ]
    (List.map
       (fun (f : Finding.t) ->
         f.check ^ if f.severity = Advisory then " advisory" else " error")
       findings);
  case "complexity: a flat enum-to-string match adds nothing" ~expect:[]
    (checks
       (Complexity.check config
          (parse
             ("let name = function\n"
             ^ lines 15 (fun i -> Printf.sprintf "  | C%d -> \"c%d\"" i i)))))

(* --- file length --- *)

let () =
  case "file_length: an .ml over the limit is caught" ~expect:[ "file_length" ]
    (checks
       (File_length.check config ~path:"lib/m.ml"
          (lines 301 (fun i -> Printf.sprintf "let v%d = ()" i))));
  case "file_length: .mli documentation does not count" ~expect:[]
    (checks
       (File_length.check config ~path:"lib/m.mli"
          ("(** Docs.\n"
          ^ lines 400 (fun _ -> "    more docs")
          ^ "*)\nval f : int\n")))

(* --- .mli coverage --- *)

let () =
  case "mli_coverage: a library module without an interface is caught"
    ~expect:[ "a/lib/no_intf.ml" ]
    (List.map
       (fun (f : Finding.t) -> f.path)
       (Mli_coverage.check config
          [
            "a/lib/no_intf.ml";
            "a/lib/intf.ml";
            "a/lib/intf.mli";
            "a/bin/main.ml";
          ]))

(* --- layers --- *)

let layered =
  match
    Config.parse
      "root .\n\
       layer base src/base/**\n\
       layer core src/core/**\n\
       layer program src/games/{game}/programs/{program}/**\n\
       layer game src/games/{game}/**\n\
       allow base base\n\
       allow core core base\n\
       allow game game core base\n\
       allow program program game core base\n"
  with
  | Ok c -> c
  | Error e -> failwith e

let library name deps =
  Printf.sprintf "(library\n (name %s)\n (public_name p.%s)\n (libraries %s))\n"
    name name (String.concat " " deps)

let tree extra =
  [
    ("src/base/wire/lib/dune", library "wire" [ "yojson" ]);
    ("src/core/effects/lib/dune", library "effects" [ "p.wire" ]);
    ("src/games/frlg/readers/lib/dune", library "frlg_readers" [ "p.effects" ]);
    ( "src/games/emerald/readers/lib/dune",
      library "emerald_readers" [ "p.effects" ] );
    ("src/games/frlg/programs/poc/lib/dune", library "poc" [ "p.frlg_readers" ]);
  ]
  @ extra

let layer_findings extra = checks (Layers.check layered (tree extra))

let () =
  case "layers: a program using its own game, and core using base, pass"
    ~expect:[] (layer_findings []);
  case "layers: a game linking another game is caught" ~expect:[ "layers" ]
    (layer_findings
       [
         ( "src/games/frlg/maps/lib/dune",
           library "frlg_maps" [ "p.emerald_readers" ] );
       ]);
  case "layers: a program linking another program is caught"
    ~expect:[ "layers" ]
    (layer_findings
       [
         ( "src/games/frlg/programs/other/test/dune",
           "(test (name t) (libraries p.poc))" );
       ]);
  case "layers: base linking core is caught" ~expect:[ "layers" ]
    (layer_findings
       [ ("src/base/codec/lib/dune", library "codec" [ "effects" ]) ])

(* --- exceptions file, parse failures, config --- *)

let () =
  case "exceptions: an entry without a reason is rejected" ~expect:[ "error" ]
    (match Lint_exceptions.parse "nesting src/a.ml\n" with
    | Ok _ -> [ "ok" ]
    | Error _ -> [ "error" ]);
  let entries =
    match
      Lint_exceptions.parse
        "nesting src/a reworked elsewhere\n\
         file_length src/gone.ml split long ago\n"
    with
    | Ok e -> e
    | Error e -> failwith e
  in
  let finding =
    Finding.error ~check:"nesting" ~path:"src/a/lib/x.ml" ~line:3 "deep"
  in
  case "exceptions: a directory entry waives, a stale entry is reported"
    ~expect:[ "exceptions" ]
    (checks (Lint_exceptions.apply ~file:"exc" entries [ finding ]));
  case "parse: a file that does not parse is a finding, not a pass"
    ~expect:[ "parse" ]
    (match Parsed_source.parse ~path:"lib/m.ml" "let f x = (x +\n" with
    | Ok _ -> []
    | Error f -> [ f.check ]);
  case "config: a missing root is an error, not an empty scan"
    ~expect:[ "error" ]
    (match
       Source_tree.files { Config.default with roots = [ "no/such/dir" ] }
     with
    | Ok _ -> [ "ok" ]
    | Error _ -> [ "error" ]);
  case "config: allow naming an undeclared layer is rejected"
    ~expect:[ "error" ]
    (match Config.parse "root .\nlayer base src/base/**\nallow base bsae\n" with
    | Ok _ -> [ "ok" ]
    | Error _ -> [ "error" ])

let () = if !failures > 0 then exit 1
