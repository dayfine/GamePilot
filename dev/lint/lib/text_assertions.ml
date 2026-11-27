open Parsetree

let rec is_string_literal (e : expression) =
  match e.pexp_desc with
  | Pexp_constant c -> Option.is_some (String_constant.text c)
  | Pexp_constraint (inner, _) -> is_string_literal inner
  | _ -> false

let is_formatter_name name =
  name = "to_string"
  || String.ends_with ~suffix:"_to_string" name
  || String.ends_with ~suffix:"_text" name

let is_formatter_ident (lid : Longident.t) =
  match lid with
  | Ldot (Lident "Printf", "sprintf") | Lident "sprintf" -> true
  | Lident name | Ldot (_, name) -> is_formatter_name name
  | Lapply _ -> false

let rec is_formatted_text (e : expression) =
  match e.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) ->
      is_formatter_ident txt
  | Pexp_constraint (inner, _) -> is_formatted_text inner
  | _ -> false

let is_equality_op (lid : Longident.t) =
  match lid with
  | Lident ("=" | "<>") | Ldot (Lident "String", "equal") -> true
  | _ -> false

let is_text_assertion (e : expression) =
  match e.pexp_desc with
  | Pexp_apply
      ( { pexp_desc = Pexp_ident { txt; _ }; _ },
        [ (Nolabel, lhs); (Nolabel, rhs) ] )
    when is_equality_op txt ->
      (is_formatted_text lhs && is_string_literal rhs)
      || (is_string_literal lhs && is_formatted_text rhs)
  | _ -> false

let default = Ast_iterator.default_iterator

let check (src : Parsed_source.t) =
  let found = ref [] in
  let expr self e =
    if is_text_assertion e then
      let line = e.pexp_loc.loc_start.pos_lnum in
      let f =
        Finding.advisory ~check:"text_assertions" ~path:src.path ~line
          "asserting formatted text against a string literal; prefer \
           structural assertions (R28)"
      in
      found := f :: !found
    else ();
    default.expr self e
  in
  let iterator = { default with expr } in
  iterator.structure iterator src.structure;
  List.rev !found
