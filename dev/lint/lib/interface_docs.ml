open Parsetree

(* The string of a [{"..."}] payload, as a doc attribute holds it. *)
let payload_string = function
  | PStr
      [ { pstr_desc = Pstr_eval ({ pexp_desc = Pexp_constant c; _ }, _); _ } ]
    ->
      String_constant.text c
  | _ -> None

let doc_string (a : attribute) =
  if a.attr_name.txt <> "ocaml.doc" then None else payload_string a.attr_payload

(* The item's doc comments, joined; empty when it has none (or only blank
   ones). *)
let doc attrs =
  String.trim (String.concat "\n" (List.filter_map doc_string attrs))

let is_word_char ch =
  match ch with
  | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '\'' -> true
  | _ -> false

let boundary text i =
  i < 0 || i >= String.length text || not (is_word_char text.[i])

let word_at text i word =
  let n = String.length word in
  i + n <= String.length text
  && String.sub text i n = word
  && boundary text (i - 1)
  && boundary text (i + n)

(* [word] occurs in [text] with no identifier character on either side. *)
let names text word =
  word <> ""
  && Seq.exists
       (fun i -> word_at text i word)
       (Seq.init (String.length text) Fun.id)

let finding ~path (loc : Location.t) message =
  Finding.error ~check:"interface_docs" ~path ~line:loc.loc_start.pos_lnum
    (message ^ " (R11)")

(* A constructor (or exception) with no doc of its own, unless the doc of the
   type it belongs to names it. *)
let unnamed_constructor ~path what ~owner_doc (name : string Location.loc) attrs
    =
  if doc attrs <> "" || names owner_doc name.txt then []
  else
    let message = Printf.sprintf "%s %s has no doc comment" what name.txt in
    [ finding ~path name.loc message ]

let constructor_findings ~path owner_doc (cd : constructor_declaration) =
  unnamed_constructor ~path "constructor" ~owner_doc cd.pcd_name
    cd.pcd_attributes

let extension_findings ~path what owner_doc (ec : extension_constructor) =
  unnamed_constructor ~path what ~owner_doc ec.pext_name ec.pext_attributes

let fields_documented = function
  | Ptype_record labels ->
      List.exists (fun l -> doc l.pld_attributes <> "") labels
  | _ -> false

let type_finding ~path (td : type_declaration) =
  let name = td.ptype_name.txt in
  if fields_documented td.ptype_kind then
    finding ~path td.ptype_loc
      (Printf.sprintf "type %s documents only its fields: say what the whole is"
         name)
  else
    finding ~path td.ptype_loc
      (Printf.sprintf "type %s has no doc comment" name)

let type_findings ~path (td : type_declaration) =
  let type_doc = doc td.ptype_attributes in
  let own = if type_doc = "" then [ type_finding ~path td ] else [] in
  match (td.ptype_kind, td.ptype_manifest) with
  | Ptype_variant cds, None ->
      own @ List.concat_map (constructor_findings ~path type_doc) cds
  | _ -> own

let value_findings ~path (vd : value_description) =
  if doc vd.pval_attributes <> "" then []
  else
    [
      finding ~path vd.pval_loc
        (Printf.sprintf "val %s has no doc comment" vd.pval_name.txt);
    ]

let rec module_type_findings ~path mt =
  match mt.pmty_desc with
  | Pmty_signature items -> signature_findings ~path items
  | Pmty_functor (_, result) -> module_type_findings ~path result
  | Pmty_with (mt, _) -> module_type_findings ~path mt
  | _ -> []

and item_findings ~path item =
  match item.psig_desc with
  | Psig_value vd -> value_findings ~path vd
  | Psig_type (_, tds) -> List.concat_map (type_findings ~path) tds
  | Psig_typext te ->
      List.concat_map
        (extension_findings ~path "constructor" (doc te.ptyext_attributes))
        te.ptyext_constructors
  | Psig_exception te ->
      extension_findings ~path "exception" (doc te.ptyexn_attributes)
        te.ptyexn_constructor
  | Psig_module md -> module_type_findings ~path md.pmd_type
  | Psig_recmodule mds ->
      List.concat_map (fun md -> module_type_findings ~path md.pmd_type) mds
  | Psig_modtype { pmtd_type = Some mt; _ } -> module_type_findings ~path mt
  | _ -> []

and signature_findings ~path items = List.concat_map (item_findings ~path) items

let check ~path text =
  let lexbuf = Lexing.from_string text in
  Lexing.set_filename lexbuf path;
  match Parse.interface lexbuf with
  | items -> signature_findings ~path items
  | exception _ ->
      [
        Finding.error ~check:"parse" ~path ~line:lexbuf.lex_curr_p.pos_lnum
          "does not parse; its docs were not checked";
      ]
