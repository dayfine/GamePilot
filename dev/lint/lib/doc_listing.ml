let found_at text i pattern =
  let n = String.length pattern in
  i + n <= String.length text && String.sub text i n = pattern

(* The first offset at or after [i] where [pattern] starts. *)
let rec find_from text i pattern =
  if i + String.length pattern > String.length text then None
  else if found_at text i pattern then Some i
  else find_from text (i + 1) pattern

(* [(open, close)] offsets of the first [opening ... closing] at or after
   [i]. *)
let span text i ~opening ~closing =
  match find_from text i opening with
  | None -> None
  | Some start ->
      find_from text (start + String.length opening) closing
      |> Option.map (fun stop -> (start, stop))

(* Every [opening ... closing] from [i] on: its start and the text between. *)
let rec spans text i ~opening ~closing =
  match span text i ~opening ~closing with
  | None -> []
  | Some (start, stop) ->
      let inner = String.length opening in
      (start, String.sub text (start + inner) (stop - start - inner))
      :: spans text (stop + String.length closing) ~opening ~closing

(* [A.B.v] as [("A.B", "v")] when [v] is a value name. *)
let reference body =
  match String.rindex_opt body '.' with
  | Some i
    when i + 1 < String.length body
         && Char.lowercase_ascii body.[i + 1] = body.[i + 1] ->
      Some
        ( String.sub body 0 i,
          String.sub body (i + 1) (String.length body - i - 1) )
  | _ -> None

let modules_listing refs value =
  List.filter_map (fun (m, v) -> if v = value then Some m else None) refs
  |> List.sort_uniq compare

(* The registration values this comment lists from two or more modules. *)
let listed values comment =
  let refs =
    spans comment 0 ~opening:"{!" ~closing:"}"
    |> List.filter_map (fun (_, b) -> reference b)
  in
  List.filter (fun v -> List.length (modules_listing refs v) > 1) values

(* 1-based: the lines up to and including the one [offset] is on. *)
let line_of text offset =
  List.length (String.split_on_char '\n' (String.sub text 0 offset))

let finding ~path ~line value =
  Finding.error ~check:"doc_listing" ~path ~line
    (Printf.sprintf
       "the doc lists %s of several modules: say what this does instead (R1)"
       value)

let comment_findings (c : Config.t) ~path text (offset, comment) =
  List.map
    (finding ~path ~line:(line_of text offset))
    (listed c.doc_listing comment)

let check (c : Config.t) ~path text =
  if c.doc_listing = [] || not (Filename.check_suffix path ".mli") then []
  else
    spans text 0 ~opening:"(**" ~closing:"*)"
    |> List.concat_map (comment_findings c ~path text)
