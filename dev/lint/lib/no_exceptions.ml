open Parsetree

let raising_functions = [ "raise"; "raise_notrace"; "failwith"; "invalid_arg" ]

let raising_name (lid : Longident.t) =
  match lid with
  | Lident name | Ldot (Lident "Stdlib", name) ->
      if List.mem name raising_functions then Some name else None
  | _ -> None

let rec catches_exception p =
  match p.ppat_desc with
  | Ppat_exception _ -> true
  | Ppat_or (a, b) -> catches_exception a || catches_exception b
  | Ppat_alias (p, _) | Ppat_constraint (p, _) -> catches_exception p
  | _ -> false

(* What an expression does with exceptions, when it does anything. *)
let expr_message e =
  match e.pexp_desc with
  | Pexp_ident { txt; _ } ->
      raising_name txt |> Option.map (Printf.sprintf "raises with %s")
  | Pexp_try _ -> Some "catches an exception with try ... with"
  | Pexp_match (_, cases)
    when List.exists (fun c -> catches_exception c.pc_lhs) cases ->
      Some "catches an exception with match ... with exception"
  | Pexp_letexception _ -> Some "declares a local exception"
  | _ -> None

let item_message item =
  match item.pstr_desc with
  | Pstr_exception _ -> Some "declares an exception"
  | Pstr_typext { ptyext_path = { txt = Lident "exn"; _ }; _ } ->
      Some "extends exn"
  | _ -> None

let finding (src : Parsed_source.t) (loc : Location.t) what =
  let line = loc.loc_start.pos_lnum in
  let message = what ^ "; return a Result instead" in
  Finding.error ~check:"no_exceptions" ~path:src.path ~line message

let default = Ast_iterator.default_iterator

let check (src : Parsed_source.t) =
  let found = ref [] in
  let report loc =
    Option.iter (fun m -> found := finding src loc m :: !found)
  in
  let expr self e =
    report e.pexp_loc (expr_message e);
    default.expr self e
  in
  let structure_item self item =
    report item.pstr_loc (item_message item);
    default.structure_item self item
  in
  let iterator = { default with expr; structure_item } in
  iterator.structure iterator src.structure;
  List.rev !found
