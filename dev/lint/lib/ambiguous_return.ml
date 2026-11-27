open Parsetree

let rec return_type (ct : core_type) =
  match ct.ptyp_desc with
  | Ptyp_arrow (_, _, res) -> return_type res
  | Ptyp_poly (_, inner) -> return_type inner
  | _ -> ct

let is_option_ctor (lid : Longident.t) =
  match lid with
  | Lident "option"
  | Ldot (Lident "Stdlib", "option")
  | Ldot (Lident "Option", "t") ->
      true
  | _ -> false

let is_result_ctor (lid : Longident.t) =
  match lid with
  | Lident "result"
  | Ldot (Lident "Stdlib", "result")
  | Ldot (Lident "Result", "t") ->
      true
  | _ -> false

let is_bool (ct : core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, []) -> (
      match txt with
      | Lident "bool"
      | Ldot (Lident "Stdlib", "bool")
      | Ldot (Lident "Bool", "t") ->
          true
      | _ -> false)
  | _ -> false

let ambiguous_kind (ct : core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt; _ }, [ inner ]) when is_option_ctor txt -> (
      match inner.ptyp_desc with
      | Ptyp_constr ({ txt = inner_txt; _ }, _) when is_result_ctor inner_txt ->
          Some "result option"
      | Ptyp_constr ({ txt = inner_txt; _ }, _) when is_option_ctor inner_txt ->
          Some "option option"
      | _ -> None)
  | Ptyp_tuple [ a; b ] when is_bool a && is_bool b -> Some "bool * bool"
  | _ -> None

let make_finding ~path (vd : value_description) kind =
  let line = vd.pval_loc.loc_start.pos_lnum in
  let message =
    Printf.sprintf
      "val %s returns ambiguous type '%s'; use a named variant (R19)"
      vd.pval_name.txt kind
  in
  Finding.error ~check:"ambiguous_return" ~path ~line message

let value_finding ~path (vd : value_description) =
  let ret = return_type vd.pval_type in
  Option.map (make_finding ~path vd) (ambiguous_kind ret)

let default = Ast_iterator.default_iterator

let collect ~path items =
  let found = ref [] in
  let value_description self vd =
    Option.iter (fun f -> found := f :: !found) (value_finding ~path vd);
    default.value_description self vd
  in
  let iterator = { default with value_description } in
  iterator.signature iterator items;
  List.rev !found

let check ~path text =
  match Parsed_source.parse_interface ~path text with
  | Error f -> [ f ]
  | Ok items -> collect ~path items
