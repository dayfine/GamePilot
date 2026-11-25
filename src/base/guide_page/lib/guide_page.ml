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

(* Hand-written paragraphs. A line is skipped (inside a block, a code fence or
   an indented code block), breaks the paragraph (blank, a heading, a table
   row, a comment, a marker or a fence), starts one (a list item, or the first
   line after a break) or continues the open one. *)

type line_kind = Skip | Break | Item | Prose

type para_state = {
  in_block : bool;
  in_fence : bool;
  para : (int * int) option;  (** The open paragraph's first line and length. *)
  long : (int * int) list;
}

let is_list_item t =
  String.starts_with ~prefix:"- " t
  || String.starts_with ~prefix:"* " t
  ||
  match String.index_opt t '.' with
  | Some i when i > 0 && i + 1 < String.length t && t.[i + 1] = ' ' ->
      String.for_all (fun c -> c >= '0' && c <= '9') (String.sub t 0 i)
  | _ -> false

let breaks t =
  t = ""
  || List.exists
       (fun prefix -> String.starts_with ~prefix t)
       [ "#"; "|"; "<!--" ]

let kind st line =
  let t = String.trim line in
  if parse_start line <> None || is_end line then Break
  else if st.in_block then Skip
  else if String.starts_with ~prefix:"```" t then Break
  else if st.in_fence then Skip
  else if breaks t then Break
  else if is_list_item t then Item
  else if st.para = None && String.starts_with ~prefix:"    " line then Skip
  else Prose

let close max_lines st =
  match st.para with
  | Some (first, n) when n > max_lines ->
      { st with para = None; long = (first, n) :: st.long }
  | _ -> { st with para = None }

let toggles st line =
  let t = String.trim line in
  {
    st with
    in_block =
      (if parse_start line <> None then true
       else if is_end line then false
       else st.in_block);
    in_fence =
      (if (not st.in_block) && String.starts_with ~prefix:"```" t then
         not st.in_fence
       else st.in_fence);
  }

let para_step max_lines (no, st) line =
  let st =
    match (kind st line, st.para) with
    | Skip, _ -> st
    | Break, _ -> toggles (close max_lines st) line
    | Item, _ | Prose, None -> { (close max_lines st) with para = Some (no, 1) }
    | Prose, Some (first, n) -> { st with para = Some (first, n + 1) }
  in
  (no + 1, st)

let long_paragraphs ~max_lines text =
  let start = { in_block = false; in_fence = false; para = None; long = [] } in
  let _, st =
    List.fold_left (para_step max_lines) (1, start) (fst (lines text))
  in
  List.rev (close max_lines st).long
