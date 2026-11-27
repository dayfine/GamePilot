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

(* --- doc_listing --- *)

let listing_config = { config with doc_listing = [ "handlers" ] }
let listing text = Doc_listing.check listing_config ~path:"lib/m.mli" text

let () =
  case "doc_listing: a doc naming two modules' handlers is caught"
    ~expect:[ "doc_listing" ]
    (checks
       (listing
          "val handlers : t\n\
           (** Ours, then {!A.handlers} and\n\
          \    {!B.C.handlers}. *)\n"));
  case "doc_listing: one other module's handlers is a pointer, not a list"
    ~expect:[]
    (checks (listing "(** Built like {!A.handlers}. *)\nval handlers : t\n"));
  case "doc_listing: other values of several modules pass" ~expect:[]
    (checks (listing "(** The {!A.game_steps} and {!B.game_steps} in it. *)\n"));
  case "doc_listing: the finding is at the comment's first line" ~expect:[ "2" ]
    (List.map
       (fun (f : Finding.t) -> string_of_int f.line)
       (listing "type t\n(** {!A.handlers},\n {!B.handlers} *)\n"));
  case "doc_listing: an .ml file is not checked" ~expect:[]
    (checks
       (Doc_listing.check listing_config ~path:"lib/m.ml"
          "(** {!A.handlers} {!B.handlers} *)\n"));
  case "config: doc_listing values are read" ~expect:[ "handlers"; "checks" ]
    (match Config.parse "root .\ndoc_listing handlers checks\n" with
    | Ok c -> c.doc_listing
    | Error e -> [ e ])

(* --- interface_docs --- *)

let docs text = Interface_docs.check ~path:"lib/m.mli" text
let messages findings = List.map (fun (f : Finding.t) -> f.message) findings

let () =
  case "interface_docs: a val with no doc is caught"
    ~expect:[ "interface_docs" ]
    (checks (docs "(** The module. *)\n\nval f : int -> int\n"));
  case "interface_docs: a doc right after or right before counts" ~expect:[]
    (checks
       (docs "val f : int\n(** After. *)\n\n(** Before. *)\nval g : int\n"));
  case "interface_docs: the first val of a group has no doc" ~expect:[ "1" ]
    (List.map
       (fun (f : Finding.t) -> string_of_int f.line)
       (docs "val f : int\nval g : int\n(** g only. *)\n"));
  case "interface_docs: a record documented only by its fields is caught"
    ~expect:[ "type t documents only its fields: say what the whole is (R11)" ]
    (messages (docs "type t = {\n  a : int;  (** The a. *)\n}\n"));
  case
    "interface_docs: a constructor needs its own doc or its name in the type's"
    ~expect:[ "constructor B has no doc comment (R11)" ]
    (messages
       (docs
          "(** [A] or the other. *)\n\
           type t =\n\
          \  | A\n\
          \  | B\n\
          \  | C  (** Its own. *)\n"));
  case "interface_docs: a re-export's constructors are documented at the source"
    ~expect:[]
    (checks (docs "(** M's, re-exported. *)\ntype t = M.t = A | B\n"));
  case "interface_docs: a longer word does not name a constructor"
    ~expect:[ "constructor Time has no doc comment (R11)" ]
    (messages (docs "(** Timeouts. *)\ntype t = Time\n"));
  case "interface_docs: items inside a module signature are checked"
    ~expect:[ "val g has no doc comment (R11)" ]
    (messages (docs "module M : sig\n  val g : int\nend\n"));
  case "interface_docs: exceptions and added constructors are checked"
    ~expect:
      [
        "exception E has no doc comment (R11)";
        "constructor X has no doc comment (R11)";
      ]
    (messages (docs "exception E\n\ntype t += X\n"));
  case "interface_docs: a blank doc does not count" ~expect:[ "interface_docs" ]
    (checks (docs "val f : int\n(** *)\n"));
  case "interface_docs: a file that does not parse is a finding"
    ~expect:[ "parse" ]
    (checks (docs "val f :\n"));
  case "config: interface_docs roots are read" ~expect:[ "src"; "tools" ]
    (match
       Config.parse "root .\ninterface_docs src\ninterface_docs tools\n"
     with
    | Ok c -> c.interface_docs_roots
    | Error e -> [ e ])

(* --- flat_constants (R27) --- *)

let () =
  case "flat_constants: more than max top-level numeric constants is caught"
    ~expect:[ "flat_constants" ]
    (checks
       (Flat_constants.check
          { config with flat_constants_max = 3 }
          (parse "let a = 1\nlet b = -2\nlet c = 3.5\nlet d = -. 4.0\n")));
  case "flat_constants: records, strings and counts within limit pass"
    ~expect:[]
    (checks
       (Flat_constants.check
          { config with flat_constants_max = 3 }
          (parse
             "let a = 1\n\
              let b = 2\n\
              let label = \"ok\"\n\
              let cfg = { x = 10; y = 20; z = 30; w = 40 }\n")));
  case "config: flat_constants_max is read" ~expect:[ "20" ]
    (match Config.parse "root .\nflat_constants_max 20\n" with
    | Ok c -> [ string_of_int c.flat_constants_max ]
    | Error e -> [ e ])

(* --- text_assertions (R28) --- *)

let () =
  let findings =
    Text_assertions.check
      (parse
         "let () =\n\
         \  assert (Printf.sprintf \"%d\" 1 = \"1\");\n\
         \  assert (String.equal \"x\" (item_to_string y));\n\
         \  assert (status_text s <> \"bad\");\n\
         \  assert (x = 1)\n")
  in
  case "text_assertions: formatted text vs string literal is advisory"
    ~expect:
      [
        "text_assertions advisory";
        "text_assertions advisory";
        "text_assertions advisory";
      ]
    (List.map
       (fun (f : Finding.t) ->
         f.check ^ if f.severity = Advisory then " advisory" else " error")
       findings);
  case "text_assertions: structural and non-formatter checks pass" ~expect:[]
    (checks
       (Text_assertions.check
          (parse "let () = assert (name = \"pikachu\"); assert (a = b)\n")))

(* --- variant_with_suffix (R17) --- *)

let () =
  case "variant_with_suffix: *_with_* constructor in .ml is caught"
    ~expect:[ "variant_with_suffix"; "variant_with_suffix" ]
    (checks
       (Variant_with_suffix.check_implementation
          (parse "type t = Plain | Walk_with_timeout of int | Run_With_Retry\n")));
  case "variant_with_suffix: *_with_* constructor in .mli is caught"
    ~expect:[ "variant_with_suffix" ]
    (checks
       (Variant_with_suffix.check_interface ~path:"lib/m.mli"
          "type t = Ok_state | Retry_with_backoff\n"));
  case "variant_with_suffix: plain constructors and re-exports pass" ~expect:[]
    (checks
       (Variant_with_suffix.check_interface ~path:"lib/m.mli"
          "type a = With_lead | Plain\ntype b = M.t = Reexport_with_other\n"))

(* --- ambiguous_return (R19) --- *)

let () =
  case "ambiguous_return: result option, option option, bool * bool are caught"
    ~expect:[ "ambiguous_return"; "ambiguous_return"; "ambiguous_return" ]
    (checks
       (Ambiguous_return.check ~path:"lib/m.mli"
          "val a : int -> (int, string) result option\n\
           val b : string -> int option option\n\
           val c : unit -> bool * bool\n"));
  case "ambiguous_return: option result, plain result and named types pass"
    ~expect:[]
    (checks
       (Ambiguous_return.check ~path:"lib/m.mli"
          "val a : int -> (int option, string) result\n\
           val b : (bool * bool) -> int\n\
           val c : unit -> bool\n"))

(* --- direct_io (A1) --- *)

let () =
  case "direct_io: Unix, In_channel and open Out_channel are caught"
    ~expect:[ "direct_io"; "direct_io"; "direct_io" ]
    (checks
       (Direct_io.check
          (parse
             "open Out_channel\n\
              let f () = Unix.sleep 1; ignore (In_channel.open_bin \"x\")\n")));
  case "direct_io: effect calls and Stdlib pass" ~expect:[]
    (checks
       (Direct_io.check
          (parse "let f () = Effects.now (); List.length [ 1; 2 ]\n")));
  case "direct_io: in_scope matches game programs and actions only"
    ~expect:[ "true"; "true"; "true"; "false"; "false" ]
    (List.map string_of_bool
       [
         Direct_io.in_scope "src/games/pokemon/frlg/programs/ace/lib/a.ml";
         Direct_io.in_scope "src/games/pokemon/plza/actions/story/lib/a.ml";
         Direct_io.in_scope "src/games/other/programs/p/lib/a.ml";
         Direct_io.in_scope "src/core/live/lib/a.ml";
         Direct_io.in_scope "src/games/pokemon/frlg/series/lib/a.ml";
       ])

let () = if !failures > 0 then exit 1
