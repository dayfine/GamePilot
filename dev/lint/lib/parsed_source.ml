open Parsetree

type t = {
  path : string;
  text : string;
  lines : string array;
  structure : Parsetree.structure;
}

type function_binding = {
  name : string;
  start_line : int;
  end_line : int;
  body : Parsetree.expression;
}

let parse ~path text =
  let lexbuf = Lexing.from_string text in
  Lexing.set_filename lexbuf path;
  match Parse.implementation lexbuf with
  | structure ->
      let lines = String.split_on_char '\n' text |> Array.of_list in
      Ok { path; text; lines; structure }
  | exception _ ->
      let line = lexbuf.lex_curr_p.pos_lnum in
      Error
        (Finding.error ~check:"parse" ~path ~line
           "does not parse; no other check ran on this file")

let parse_interface ~path text =
  let lexbuf = Lexing.from_string text in
  Lexing.set_filename lexbuf path;
  match Parse.interface lexbuf with
  | items -> Ok items
  | exception _ ->
      let line = lexbuf.lex_curr_p.pos_lnum in
      Error
        (Finding.error ~check:"parse" ~path ~line
           "does not parse; no other check ran on this file")

let rec is_function e =
  match e.pexp_desc with
  | Pexp_function _ -> true
  | Pexp_constraint (e, _) | Pexp_newtype (_, e) -> is_function e
  | _ -> false

let binding_name vb =
  match vb.pvb_pat.ppat_desc with
  | Ppat_var { txt; _ }
  | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _) ->
      txt
  | _ -> "<pattern>"

let of_value_binding vb =
  let loc = vb.pvb_loc in
  {
    name = binding_name vb;
    start_line = loc.loc_start.pos_lnum;
    end_line = loc.loc_end.pos_lnum;
    body = vb.pvb_expr;
  }

let rec of_module_expr me =
  match me.pmod_desc with
  | Pmod_structure s -> of_structure s
  | Pmod_constraint (me, _) | Pmod_functor (_, me) -> of_module_expr me
  | _ -> []

and of_structure s = List.concat_map of_structure_item s

and of_structure_item item =
  match item.pstr_desc with
  | Pstr_value (_, vbs) ->
      List.filter (fun vb -> is_function vb.pvb_expr) vbs
      |> List.map of_value_binding
  | Pstr_module mb -> of_module_expr mb.pmb_expr
  | Pstr_recmodule mbs ->
      List.concat_map (fun mb -> of_module_expr mb.pmb_expr) mbs
  | _ -> []

let function_bindings t = of_structure t.structure

let source_text t (loc : Location.t) =
  let start = loc.loc_start.pos_cnum and stop = loc.loc_end.pos_cnum in
  String.sub t.text start (stop - start)
