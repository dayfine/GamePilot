(* Each library of the tree, by each of its names: all its names and the
   libraries it links. *)
let owners dune_files =
  let table = Hashtbl.create (List.length dune_files) in
  let add (s : Dune_stanzas.stanza) =
    List.iter
      (fun name -> Hashtbl.replace table name (s.defines, s.libraries))
      s.defines
  in
  List.iter
    (fun (_, text) -> Result.iter (List.iter add) (Dune_stanzas.parse text))
    dune_files;
  table

let names owners lib =
  match Hashtbl.find_opt owners lib with
  | Some (defines, _) -> defines
  | None -> [ lib ]

(* The chain from [lib] to a forbidden library, [lib] first, if any. *)
let rec chain owners forbidden seen lib =
  let aliases = names owners lib in
  if List.exists (fun n -> List.mem n forbidden) aliases then Some [ lib ]
  else if List.exists (fun n -> List.mem n seen) aliases then None
  else
    let seen = aliases @ seen in
    let links = Option.fold ~none:[] ~some:snd (Hashtbl.find_opt owners lib) in
    List.find_map
      (fun next ->
        Option.map (fun rest -> lib :: rest) (chain owners forbidden seen next))
      links

let finding ~path (s : Dune_stanzas.stanza) links =
  Finding.error ~check:"never_links" ~path ~line:s.line
    (Printf.sprintf "%s links %s, which it never may" (Filename.dirname path)
       (String.concat " -> " links))

let stanza_findings owners ~path forbidden (s : Dune_stanzas.stanza) =
  List.filter_map (chain owners forbidden s.defines) s.libraries
  |> List.map (finding ~path s)

let rules_for (c : Config.t) dir =
  List.concat_map
    (fun (pattern, libs) -> if Layers.dir_matches pattern dir then libs else [])
    c.never_links

let check (c : Config.t) dune_files =
  let owners = owners dune_files in
  List.concat_map
    (fun (path, text) ->
      match (rules_for c (Filename.dirname path), Dune_stanzas.parse text) with
      | [], _ | _, Error _ -> []
      | forbidden, Ok stanzas ->
          List.concat_map (stanza_findings owners ~path forbidden) stanzas)
    dune_files
