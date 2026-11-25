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
  case "nesting: a function in a functor is measured from its let" ~expect:[]
    (checks
       (Nesting.check config
          (parse
             "module Make (T : sig end) = struct\n\
             \  let f a =\n\
             \    match a with\n\
             \    | Some b ->\n\
             \        if b then\n\
             \          1\n\
             \        else 2\n\
             \    | None -> 0\n\
              end\n")));
  case "nesting: a functor's body counts from the functor, file-wide" ~expect:[]
    (checks
       (Nesting.check config
          (parse
             "module Make (T : sig end) = struct\n\
             \  let f a =\n\
             \    match a with\n\
             \    | Some b -> b\n\
             \    | None -> 0\n\
              end\n")));
  case "nesting: the same lines at the top level are too deep"
    ~expect:[ "nesting"; "nesting" ]
    (checks
       (Nesting.check config
          (parse
             "let f a =\n\
             \        match a with\n\
             \        | Some b -> b\n\
             \        | None -> 0\n")));
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

(* --- no exceptions --- *)

let () =
  case "no_exceptions: declaring, raising and catching are caught"
    ~expect:(List.init 7 (fun _ -> "no_exceptions"))
    (checks
       (No_exceptions.check
          (parse
             "exception Stop\n\
              let a () = raise Stop\n\
              let b () = failwith \"no\"\n\
              let c f = try f () with Stop -> 0\n\
              let d f = match f () with x -> x | exception Stop -> 0\n\
              let e () = Stdlib.invalid_arg \"x\"\n\
              let g = List.map raise_notrace\n")));
  case "no_exceptions: a local exception is caught" ~expect:[ "no_exceptions" ]
    (checks (No_exceptions.check (parse "let f () = let exception E in ()\n")));
  case
    "no_exceptions: comments, strings, Result and names containing raise pass"
    ~expect:[]
    (checks
       (No_exceptions.check
          (parse
             "(* raise Stop; try ... with; failwith *)\n\
              let raise_volume v = v + 1\n\
              let msg = \"failwith: exception, try with\"\n\
              let f x = match x with Ok v -> v | Error _ -> 0\n")))

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
       layer pokemon src/pokemon/**\n\
       layer program src/games/{game}/programs/{program}/**\n\
       layer game src/games/{game}/**\n\
       allow base base\n\
       allow core core base\n\
       allow pokemon pokemon core base\n\
       allow game game pokemon core base\n\
       allow program program game pokemon core base\n\
       family pokemon game frlg\n"
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
    ("src/pokemon/party/lib/dune", library "party" [ "p.effects" ]);
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
       [ ("src/base/codec/lib/dune", library "codec" [ "effects" ]) ]);
  case "layers: a game and its program in the family may link it" ~expect:[]
    (layer_findings
       [
         ("src/games/frlg/maps/lib/dune", library "frlg_maps" [ "p.party" ]);
         ( "src/games/frlg/programs/poc/test/dune",
           "(test (name t) (libraries p.party))" );
       ]);
  case "layers: a game outside the family linking it is caught"
    ~expect:[ "layers" ]
    (layer_findings
       [
         ( "src/games/emerald/maps/lib/dune",
           library "emerald_maps" [ "p.party" ] );
       ]);
  case "layers: a program of a game outside the family is caught"
    ~expect:[ "layers" ]
    (layer_findings
       [
         ( "src/games/emerald/programs/poc/test/dune",
           "(test (name t) (libraries p.party))" );
       ])

(* --- never_links --- *)

let pure =
  match Config.parse "root .\nnever_links src/engine/rules/lib yojson\n" with
  | Ok c -> c
  | Error e -> failwith e

let never_links_findings extra =
  checks
    (Never_links.check pure
       ([
          ("src/base/wire/lib/dune", library "wire" [ "yojson" ]);
          ("src/base/text/lib/dune", library "text" []);
          ("src/engine/codec/lib/dune", library "codec" [ "p.wire" ]);
        ]
       @ extra))

let () =
  case "never_links: a rules library linking only pure libraries passes"
    ~expect:[]
    (never_links_findings
       [ ("src/engine/rules/lib/dune", library "rules" [ "p.text" ]) ]);
  case "never_links: linking the library directly is caught"
    ~expect:[ "never_links" ]
    (never_links_findings
       [ ("src/engine/rules/lib/dune", library "rules" [ "yojson" ]) ]);
  case "never_links: linking it through two libraries is caught"
    ~expect:[ "never_links" ]
    (never_links_findings
       [ ("src/engine/rules/lib/dune", library "rules" [ "codec" ]) ]);
  case "never_links: another directory may link it" ~expect:[]
    (never_links_findings
       [ ("src/engine/other/lib/dune", library "other" [ "p.codec" ]) ])

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
    | Error _ -> [ "error" ]);
  case "config: family naming an undeclared layer is rejected"
    ~expect:[ "error" ]
    (match
       Config.parse "root .\nlayer base src/base/**\nfamily bsae game a\n"
     with
    | Ok _ -> [ "ok" ]
    | Error _ -> [ "error" ])

let () =
  case "config: no_exceptions roots are read" ~expect:[ "src"; "tools" ]
    (match Config.parse "root .\nno_exceptions src\nno_exceptions tools\n" with
    | Ok c -> c.no_exceptions_roots
    | Error e -> [ e ])

let () = if !failures > 0 then exit 1
