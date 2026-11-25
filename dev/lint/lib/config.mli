(** The linter's settings: which trees to scan, thresholds, and the layer table.
    Read from a line-based file so the code names no project.

    Each non-blank line that does not start with [#] is [key value...]:
    - [root DIR] (repeatable): a tree to scan, relative to the working
      directory.
    - [skip_dir NAME] (repeatable): directory name never entered ([_build] and
      names starting with [.] are always skipped).
    - [test_dir NAME] (repeatable): directory name whose OCaml files the code
      checks skip; its dune files are still layer-checked.
    - [library_dir NAME]: directory name that holds library modules (default
      [lib]); [.mli] coverage and magic numbers apply there.
    - [exceptions FILE]: the exceptions file (see {!Lint_exceptions}).
    - [no_exceptions DIR] (repeatable): a tree whose non-test [.ml] files may
      not raise or catch exceptions (see {!No_exceptions}).
    - [max_function_lines N], [max_function_avg_depth F],
      [max_function_depth N], [max_file_avg_depth F], [max_file_lines N],
      [max_interface_lines N], [complexity_advisory N]: thresholds.
    - [layer NAME PATTERN] (repeatable, first match wins): dune directories
      matching [PATTERN] belong to layer [NAME]. A pattern is [/]-separated
      segments: a literal, [{var}] (one segment, bound to [var]) or a final [**]
      (any rest).
    - [allow NAME DEP...] (repeatable): layers [NAME] may depend on ([*] = any).
      A dependency is allowed only when every variable both sides bind has the
      same value, so [games/{game}/**] can use its own game only.
    - [family LAYER VAR VALUE...] (repeatable): a placement that binds [VAR] may
      link layer [LAYER] only when its value is one of the [VALUE]s, so
      [family shared game a b] lets games [a] and [b] use layer [shared], and no
      other game. Placements that do not bind [VAR] are not restricted. *)

type layer = { name : string; pattern : string list }

type family = { layer : string; var : string; members : string list }
(** The values of [var] whose placements may link [layer]. *)

type t = {
  roots : string list;
  skip_dirs : string list;
  test_dirs : string list;
  library_dir : string;
  exceptions_file : string option;
  no_exceptions_roots : string list;
  max_function_lines : int;
  max_function_avg_depth : float;
  max_function_depth : int;
  max_file_avg_depth : float;
  max_file_lines : int;
  max_interface_lines : int;
  complexity_advisory : int;
  layers : layer list;
  allowed : (string * string list) list;
  families : family list;
}

val default : t
(** Thresholds from [dayfine/trading]; no roots, no layers. *)

val parse : string -> (t, string) result
(** [parse text] reads a config file's contents. Unknown keys, malformed
    numbers, [allow] and [family] lines naming an undeclared layer and an empty
    root list are errors. *)
