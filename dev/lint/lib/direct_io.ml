open Parsetree

let forbidden_modules =
  [ "Unix"; "Thread"; "Domain"; "Eio"; "Lwt"; "In_channel"; "Out_channel" ]

let in_scope path =
  let rec after_games = function
    | [] -> false
    | ("programs" | "actions") :: _ -> true
    | _ :: rest -> after_games rest
  in
  let rec find_games = function
    | [] -> false
    | "games" :: rest -> after_games rest
    | _ :: rest -> find_games rest
  in
  find_games (String.split_on_char '/' path)

let rec forbidden_root (lid : Longident.t) =
  match lid with
  | Lident m -> if List.mem m forbidden_modules then Some m else None
  | Ldot (Lident "Stdlib", m) when List.mem m forbidden_modules -> Some m
  | Ldot (prefix, _) -> forbidden_root prefix
  | Lapply (a, _) -> forbidden_root a

let forbidden_ident (lid : Longident.t) =
  match lid with Ldot _ -> forbidden_root lid | Lident _ | Lapply _ -> None

let finding (src : Parsed_source.t) (loc : Location.t) mod_name =
  let line = loc.loc_start.pos_lnum in
  let message =
    Printf.sprintf
      "direct I/O via %s is forbidden in programs and actions; use effects (A1)"
      mod_name
  in
  Finding.error ~check:"direct_io" ~path:src.path ~line message

let default = Ast_iterator.default_iterator

let check (src : Parsed_source.t) =
  let found = ref [] in
  let report loc =
    Option.iter (fun m -> found := finding src loc m :: !found)
  in
  let expr self e =
    (match e.pexp_desc with
    | Pexp_ident { txt; _ } -> report e.pexp_loc (forbidden_ident txt)
    | _ -> ());
    default.expr self e
  in
  let module_expr self me =
    (match me.pmod_desc with
    | Pmod_ident { txt; _ } -> report me.pmod_loc (forbidden_root txt)
    | _ -> ());
    default.module_expr self me
  in
  let iterator = { default with expr; module_expr } in
  iterator.structure iterator src.structure;
  List.rev !found
