open Parsetree

let rec reaches_if e =
  match e.pexp_desc with
  | Pexp_ifthenelse _ -> true
  | Pexp_let (_, _, body) | Pexp_sequence (_, body) | Pexp_constraint (body, _)
    ->
      reaches_if body
  | _ -> false

let rec nested_else_count e =
  let in_cases cases =
    List.fold_left (fun n c -> n + nested_else_count c.pc_rhs) 0 cases
  in
  match e.pexp_desc with
  | Pexp_ifthenelse (_, then_e, None) -> nested_else_count then_e
  | Pexp_ifthenelse (_, then_e, Some else_e) ->
      let here =
        match else_e.pexp_desc with
        | Pexp_ifthenelse _ -> 0
        | _ -> if reaches_if else_e then 1 else 0
      in
      nested_else_count then_e + here + nested_else_count else_e
  | Pexp_function (_, _, Pfunction_body body) -> nested_else_count body
  | Pexp_function (_, _, Pfunction_cases (cases, _, _)) | Pexp_match (_, cases)
    ->
      in_cases cases
  | Pexp_let (_, _, body) | Pexp_constraint (body, _) -> nested_else_count body
  | Pexp_sequence (a, b) -> nested_else_count a + nested_else_count b
  | _ -> 0

let leading_spaces line =
  let n = String.length line in
  let rec go i = if i < n && line.[i] = ' ' then go (i + 1) else i in
  go 0

let is_code_line line =
  let t = String.trim line in
  t <> "" && (not (String.starts_with ~prefix:"(*" t)) && t.[0] <> '*'

(* Depths of the code lines in [first..last] (1-based, inclusive). *)
let depths lines ~first ~last =
  let last = min last (Array.length lines) in
  List.init (max 0 (last - first + 1)) (fun i -> lines.(first - 1 + i))
  |> List.filter is_code_line
  |> List.map (fun l -> leading_spaces l / 2)

let average = function
  | [] -> 0.0
  | ds ->
      float_of_int (List.fold_left ( + ) 0 ds) /. float_of_int (List.length ds)

let reason cond text = if cond then Some text else None

let function_finding (c : Config.t) (src : Parsed_source.t)
    (fb : Parsed_source.function_binding) =
  (* The [let] line itself is depth 0 by construction; measure the body. *)
  let ds = depths src.lines ~first:(fb.start_line + 1) ~last:fb.end_line in
  let avg = average ds and deepest = List.fold_left max 0 ds in
  let nested = nested_else_count fb.body in
  let avg_limit = c.max_function_avg_depth and limit = c.max_function_depth in
  let reasons =
    List.filter_map Fun.id
      [
        reason (avg > avg_limit)
          (Printf.sprintf "average depth %.2f > %.1f" avg avg_limit);
        reason (deepest > limit) (Printf.sprintf "depth %d > %d" deepest limit);
        reason (nested > 0)
          (Printf.sprintf "%d nested else (split the else branch out)" nested);
      ]
  in
  let message =
    Printf.sprintf "'%s': %s" fb.name (String.concat ", " reasons)
  in
  let line = fb.start_line in
  if reasons = [] then None
  else Some (Finding.error ~check:"nesting" ~path:src.path ~line message)

let check (c : Config.t) (src : Parsed_source.t) =
  let in_functions =
    Parsed_source.function_bindings src
    |> List.filter_map (function_finding c src)
  in
  let file_avg =
    average (depths src.lines ~first:1 ~last:(Array.length src.lines))
  in
  if file_avg > c.max_file_avg_depth then
    Finding.error ~check:"nesting" ~path:src.path ~line:0
      (Printf.sprintf "file average depth %.2f > %.1f" file_avg
         c.max_file_avg_depth)
    :: in_functions
  else in_functions
