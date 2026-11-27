open Parsetree

let is_digit ch = ch >= '0' && ch <= '9'

let strip_sign s =
  let drop prefix =
    String.sub s (String.length prefix) (String.length s - String.length prefix)
  in
  if String.starts_with ~prefix:"-." s then String.trim (drop "-.")
  else if String.starts_with ~prefix:"+." s then String.trim (drop "+.")
  else if String.starts_with ~prefix:"-" s then String.trim (drop "-")
  else if String.starts_with ~prefix:"+" s then String.trim (drop "+")
  else s

let is_numeric_source text =
  let unsigned = strip_sign (String.trim text) in
  String.length unsigned > 0 && is_digit unsigned.[0]

let is_unary_sign_op (e : expression) =
  match e.pexp_desc with
  | Pexp_ident { txt = Lident ("~-" | "~-." | "~+" | "~+."); _ } -> true
  | _ -> false

let rec is_numeric_expr (src : Parsed_source.t) (e : expression) =
  match e.pexp_desc with
  | Pexp_constant _ ->
      is_numeric_source (Parsed_source.source_text src e.pexp_loc)
  | Pexp_constraint (inner, _) -> is_numeric_expr src inner
  | Pexp_apply (op, [ (Nolabel, arg) ]) when is_unary_sign_op op ->
      is_numeric_expr src arg
  | _ -> false

let count_item src item =
  match item.pstr_desc with
  | Pstr_value (_, vbs) ->
      List.fold_left
        (fun acc vb -> if is_numeric_expr src vb.pvb_expr then acc + 1 else acc)
        0 vbs
  | _ -> 0

let check (c : Config.t) (src : Parsed_source.t) =
  let count =
    List.fold_left (fun acc item -> acc + count_item src item) 0 src.structure
  in
  if count <= c.flat_constants_max then []
  else
    let message =
      Printf.sprintf
        "%d top-level numeric constants (limit %d); group related constants in \
         a record (R27)"
        count c.flat_constants_max
    in
    [ Finding.error ~check:"flat_constants" ~path:src.path ~line:0 message ]
