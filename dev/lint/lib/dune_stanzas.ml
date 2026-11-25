type sexp = Atom of string | List of int * sexp list
type stanza = { line : int; defines : string list; libraries : string list }

exception Malformed of string

(* A small reader for dune's sexp syntax: atoms, quoted strings, [;] and
   [#| |#] comments. Enough for the fields read here. *)
type cursor = { text : string; mutable pos : int; mutable line : int }

let peek c = if c.pos < String.length c.text then Some c.text.[c.pos] else None

let advance c =
  if c.text.[c.pos] = '\n' then c.line <- c.line + 1;
  c.pos <- c.pos + 1

let at c s =
  c.pos + String.length s <= String.length c.text
  && String.sub c.text c.pos (String.length s) = s

(* Advances past the next [stop], or to the end. *)
let rec skip_past c stop =
  if at c stop then String.iter (fun _ -> advance c) stop
  else if peek c <> None then (
    advance c;
    skip_past c stop)

let rec skip_blank c =
  match peek c with
  | Some (' ' | '\t' | '\r' | '\n') ->
      advance c;
      skip_blank c
  | Some ';' ->
      skip_past c "\n";
      skip_blank c
  | Some '#' when at c "#|" ->
      skip_past c "|#";
      skip_blank c
  | _ -> ()

let rec quoted_rest c buf =
  match peek c with
  | None -> raise (Malformed "unterminated string")
  | Some '"' -> advance c
  | Some ch ->
      if ch = '\\' then advance c;
      Option.iter (Buffer.add_char buf) (peek c);
      advance c;
      quoted_rest c buf

let quoted c =
  let buf = Buffer.create (String.length c.text - c.pos) in
  advance c;
  quoted_rest c buf;
  Atom (Buffer.contents buf)

let is_atom_char = function
  | ' ' | '\t' | '\r' | '\n' | '(' | ')' | ';' | '"' -> false
  | _ -> true

let atom c =
  let start = c.pos in
  while Option.fold ~none:false ~some:is_atom_char (peek c) do
    advance c
  done;
  Atom (String.sub c.text start (c.pos - start))

let rec value c =
  skip_blank c;
  match peek c with
  | Some '(' ->
      let line = c.line in
      advance c;
      List (line, items c [])
  | Some ')' ->
      raise (Malformed (Printf.sprintf "line %d: unexpected ')'" c.line))
  | Some '"' -> quoted c
  | _ -> atom c

and items c acc =
  skip_blank c;
  match peek c with
  | None -> raise (Malformed "unclosed '('")
  | Some ')' ->
      advance c;
      List.rev acc
  | Some _ -> items c (value c :: acc)

let read_sexps text =
  let c = { text; pos = 0; line = 1 } in
  let rec top acc =
    skip_blank c;
    if peek c = None then List.rev acc else top (value c :: acc)
  in
  top []

let field name fields =
  let values = function
    | List (_, Atom key :: values) when key = name -> Some values
    | _ -> None
  in
  Option.value ~default:[] (List.find_map values fields)

let atoms values =
  List.filter_map (function Atom a -> Some a | List _ -> None) values

let library_names values =
  List.concat_map
    (function
      | Atom a -> [ a ]
      | List (_, [ Atom "re_export"; Atom a ]) -> [ a ]
      | List _ -> [])
    values

let stanza_of = function
  | List (line, Atom kind :: fields) ->
      let defines =
        if kind = "library" then
          atoms (field "name" fields) @ atoms (field "public_name" fields)
        else []
      in
      let libraries = library_names (field "libraries" fields) in
      if defines = [] && libraries = [] then None
      else Some { line; defines; libraries }
  | _ -> None

let parse text =
  match read_sexps text with
  | sexps -> Ok (List.filter_map stanza_of sexps)
  | exception Malformed e -> Error e
