open Parsetree

let exempt_floats =
  [ "0."; "0.0"; "0.5"; "1."; "1.0"; "2."; "2.0"; "100."; "100.0" ]

let is_digit ch = ch >= '0' && ch <= '9'

(* A literal's source text, without sign and digit separators, when it is a
   magic number; [None] for exempt numbers and for strings and chars. *)
let magic_text text =
  let unsigned =
    if String.starts_with ~prefix:"-" text then
      String.sub text 1 (String.length text - 1)
    else text
  in
  let digits = String.concat "" (String.split_on_char '_' unsigned) in
  if digits = "" || not (is_digit digits.[0]) then None
  else if String.exists (fun ch -> ch = '.' || ch = 'e' || ch = 'E') digits then
    if List.mem digits exempt_floats then None else Some text
  else if String.length digits >= 2 then Some text
  else None

let rec is_literal e =
  match e.pexp_desc with
  | Pexp_constant _ -> true
  | Pexp_constraint (e, _) -> is_literal e
  | _ -> false

let finding (src : Parsed_source.t) (loc : Location.t) =
  let line = loc.loc_start.pos_lnum in
  let named text = Printf.sprintf "bare literal %s; give it a name" text in
  magic_text (Parsed_source.source_text src loc)
  |> Option.map (fun text ->
         Finding.error ~check:"magic_numbers" ~path:src.path ~line (named text))

let default = Ast_iterator.default_iterator

let visit_unless_literal (self : Ast_iterator.iterator) e =
  if not (is_literal e) then self.expr self e

(* A literal default ([?(retries = 3)]) is a named value. *)
let visit_param (self : Ast_iterator.iterator) p =
  match p.pparam_desc with
  | Pparam_val (_, default_value, pat) ->
      Option.iter (visit_unless_literal self) default_value;
      self.pat self pat
  | Pparam_newtype _ -> ()

let visit_function_body (self : Ast_iterator.iterator) = function
  | Pfunction_body e -> self.expr self e
  | Pfunction_cases (cases, _, _) -> self.cases self cases

let expr report (self : Ast_iterator.iterator) e =
  match e.pexp_desc with
  | Pexp_constant _ -> report e.pexp_loc
  | Pexp_record (fields, base) ->
      List.iter (fun (_, v) -> visit_unless_literal self v) fields;
      Option.iter (self.expr self) base
  | Pexp_function (params, _, body) ->
      List.iter (visit_param self) params;
      visit_function_body self body
  | _ -> default.expr self e

let value_binding self vb =
  if not (is_literal vb.pvb_expr) then default.value_binding self vb

let check (src : Parsed_source.t) =
  let found = ref [] in
  let report loc =
    Option.iter (fun f -> found := f :: !found) (finding src loc)
  in
  let iterator = { default with expr = expr report; value_binding } in
  iterator.structure iterator src.structure;
  List.rev !found
