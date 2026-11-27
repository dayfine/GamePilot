open Parsetree

let needle = "_with_"

let has_with_infix name =
  let lower = String.lowercase_ascii name in
  let n = String.length lower in
  let m = String.length needle in
  let rec scan i =
    if i + m >= n then false
    else if String.sub lower i m = needle then true
    else scan (i + 1)
  in
  n > m + 1 && scan 1

let constructor_finding ~path (cd : constructor_declaration) =
  let name = cd.pcd_name.txt in
  if not (has_with_infix name) then None
  else
    let line = cd.pcd_name.loc.loc_start.pos_lnum in
    let message =
      Printf.sprintf
        "constructor %s uses a '_with_' suffix; name the variant for what it \
         is (R17)"
        name
    in
    Some (Finding.error ~check:"variant_with_suffix" ~path ~line message)

let default = Ast_iterator.default_iterator

let type_findings ~path (td : type_declaration) =
  match (td.ptype_kind, td.ptype_manifest) with
  | Ptype_variant cds, None -> List.filter_map (constructor_finding ~path) cds
  | _ -> []

let collect ~path walk =
  let found = ref [] in
  let type_declaration self (td : type_declaration) =
    List.iter (fun f -> found := f :: !found) (type_findings ~path td);
    default.type_declaration self td
  in
  let iterator = { default with type_declaration } in
  walk iterator;
  List.rev !found

let check_implementation (src : Parsed_source.t) =
  collect ~path:src.path (fun it -> it.structure it src.structure)

let check_interface ~path text =
  match Parsed_source.parse_interface ~path text with
  | Error f -> [ f ]
  | Ok items -> collect ~path (fun it -> it.signature it items)
