type placement = { layer : string; bindings : (string * string) list }

let rec match_segments pattern segments bindings =
  match (pattern, segments) with
  | [ "**" ], _ -> Some bindings
  | [], [] -> Some bindings
  | p :: ps, s :: ss ->
      let n = String.length p in
      if n > 2 && p.[0] = '{' && p.[n - 1] = '}' then
        match_segments ps ss ((String.sub p 1 (n - 2), s) :: bindings)
      else if p = s then match_segments ps ss bindings
      else None
  | _ -> None

let place (c : Config.t) dir =
  let segments = String.split_on_char '/' dir in
  List.find_map
    (fun (l : Config.layer) ->
      match_segments l.pattern segments []
      |> Option.map (fun bindings -> { layer = l.name; bindings }))
    c.layers

let describe p =
  match p.bindings with
  | [] -> p.layer
  | bs ->
      Printf.sprintf "%s (%s)" p.layer
        (String.concat ", " (List.rev_map (fun (k, v) -> k ^ "=" ^ v) bs))

let in_family from (f : Config.family) =
  match List.assoc_opt f.var from.bindings with
  | None -> true
  | Some v -> List.mem v f.members

let family_allows (c : Config.t) from target =
  List.for_all
    (fun (f : Config.family) -> f.layer <> target.layer || in_family from f)
    c.families

let allows (c : Config.t) from target =
  let permitted =
    List.concat_map
      (fun (name, deps) -> if name = from.layer then deps else [])
      c.allowed
  in
  let layer_ok = List.mem "*" permitted || List.mem target.layer permitted in
  let bindings_agree =
    List.for_all
      (fun (k, v) ->
        match List.assoc_opt k target.bindings with
        | None -> true
        | Some w -> v = w)
      from.bindings
  in
  layer_ok && bindings_agree && family_allows c from target

let dep_message c ~from lib target =
  let outside = "which is outside every layer" in
  match target with
  | None -> Some (Printf.sprintf "%s links %s, %s" (describe from) lib outside)
  | Some t when allows c from t -> None
  | Some t ->
      let target = describe t in
      Some (Printf.sprintf "%s may not link %s (%s)" (describe from) lib target)

let dep_finding c ~path ~line ~from ~owners lib =
  Hashtbl.find_opt owners lib
  |> Option.map (dep_message c ~from lib)
  |> Option.join
  |> Option.map (Finding.error ~check:"layers" ~path ~line)

let add_owners c owners (path, result) =
  let placement = place c (Filename.dirname path) in
  let add (s : Dune_stanzas.stanza) =
    List.iter (fun name -> Hashtbl.replace owners name placement) s.defines
  in
  Result.iter (List.iter add) result

let stanza_findings c ~owners ~path ~from (s : Dune_stanzas.stanza) =
  List.filter_map (dep_finding c ~path ~line:s.line ~from ~owners) s.libraries

let file_findings c ~owners (path, result) =
  match (result, place c (Filename.dirname path)) with
  | Error e, _ ->
      let message = "dune file does not parse: " ^ e in
      [ Finding.error ~check:"layers" ~path ~line:0 message ]
  | Ok _, None -> []
  | Ok stanzas, Some from ->
      List.concat_map (stanza_findings c ~owners ~path ~from) stanzas

let check (c : Config.t) dune_files =
  let parse (path, text) = (path, Dune_stanzas.parse text) in
  let parsed = List.map parse dune_files in
  let owners = Hashtbl.create (List.length dune_files) in
  List.iter (add_owners c owners) parsed;
  List.concat_map (file_findings c ~owners) parsed
