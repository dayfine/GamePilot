type block = { name : string; arg : string option; body : string }

let end_marker = "<!-- /generated -->"
let start_prefix = "<!-- generated:"
let start_suffix = " -->"

let start_marker name arg =
  start_prefix
  ^ (match arg with None -> name | Some a -> name ^ " " ^ a)
  ^ start_suffix

(* [Some (name, arg)] for a start marker line. *)
let parse_start line =
  let line = String.trim line in
  if
    String.starts_with ~prefix:start_prefix line
    && String.ends_with ~suffix:start_suffix line
  then
    let n = String.length start_prefix in
    let inner =
      String.sub line n (String.length line - n - String.length start_suffix)
    in
    match String.split_on_char ' ' (String.trim inner) with
    | [ name ] when name <> "" -> Some (name, None)
    | [ name; arg ] when name <> "" -> Some (name, Some arg)
    | _ -> None
  else None

let is_end line = String.trim line = end_marker

(* A piece of the page: a line outside every block, or a block with the
   markers' lines. *)
type piece = Text of string | Block of block * string * string

let lines text =
  match List.rev (String.split_on_char '\n' text) with
  | "" :: rest -> (List.rev rest, true)
  | all -> (List.rev all, false)

let ( let* ) = Result.bind
let error n what = Error (Printf.sprintf "line %d: %s" n what)

(* The block being read: its start line's number and text, and its body so
   far, last line first. *)
type reading = {
  start_no : int;
  start : string;
  name : string;
  arg : string option;
  rest : string list;
}

type state = { reading : reading option; acc : piece list }

let outside n st line =
  match parse_start line with
  | Some (name, arg) ->
      Ok
        {
          st with
          reading = Some { start_no = n; start = line; name; arg; rest = [] };
        }
  | None when is_end line -> error n (end_marker ^ " with no block open")
  | None -> Ok { st with acc = Text line :: st.acc }

let inside n st r line =
  if parse_start line <> None then
    error n
      (Printf.sprintf "a block starts inside the block of line %d" r.start_no)
  else if is_end line then
    let body = String.concat "" (List.rev_map (fun l -> l ^ "\n") r.rest) in
    let block = { name = r.name; arg = r.arg; body } in
    Ok { reading = None; acc = Block (block, r.start, line) :: st.acc }
  else Ok { st with reading = Some { r with rest = line :: r.rest } }

let step (n, st) line =
  let* st =
    match st.reading with
    | None -> outside n st line
    | Some r -> inside n st r line
  in
  Ok (n + 1, st)

let parse text =
  let* _, st =
    List.fold_left
      (fun acc line -> Result.bind acc (fun ns -> step ns line))
      (Ok (1, { reading = None; acc = [] }))
      (fst (lines text))
  in
  match st.reading with
  | None -> Ok (List.rev st.acc)
  | Some r -> error r.start_no ("no " ^ end_marker ^ " for this block")

let blocks text =
  let* ps = parse text in
  Ok
    (List.filter_map (function Block (b, _, _) -> Some b | Text _ -> None) ps)

let with_newline s =
  if s = "" || String.ends_with ~suffix:"\n" s then s else s ^ "\n"

let render generate = function
  | Text line -> Ok (line ^ "\n")
  | Block (b, start, stop) ->
      let* body = generate b in
      Ok (start ^ "\n" ^ with_newline body ^ stop ^ "\n")

let fill generate text =
  let* ps = parse text in
  let* parts =
    List.fold_left
      (fun acc p ->
        let* acc = acc in
        let* part = render generate p in
        Ok (part :: acc))
      (Ok []) ps
  in
  let page = String.concat "" (List.rev parts) in
  if snd (lines text) then Ok page
  else Ok (String.sub page 0 (max 0 (String.length page - 1)))
