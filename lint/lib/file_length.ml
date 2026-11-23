let is_blank ch = ch = ' ' || ch = '\t' || ch = '\r'

(* Scans [line] from [i] at comment depth [depth]; returns the depth at the
   end of the line and whether any code sits outside comments. *)
let rec scan line i depth code =
  let pair = if i + 1 < String.length line then String.sub line i 2 else "" in
  if i >= String.length line then (depth, code)
  else if pair = "(*" then scan line (i + 2) (depth + 1) code
  else if pair = "*)" && depth > 0 then scan line (i + 2) (depth - 1) code
  else scan line (i + 1) depth (code || (depth = 0 && not (is_blank line.[i])))

(* Lines with code left after removing (possibly nested) comments. *)
let signature_lines text =
  let count (depth, n) line =
    let depth, code = scan line 0 depth false in
    (depth, if code then n + 1 else n)
  in
  snd (List.fold_left count (0, 0) (String.split_on_char '\n' text))

let raw_lines text =
  let n = List.length (String.split_on_char '\n' text) in
  if String.ends_with ~suffix:"\n" text then n - 1 else n

let finding ~path ~count ~limit what =
  [
    Finding.error ~check:"file_length" ~path ~line:0
      (Printf.sprintf "%d %s (limit %d)" count what limit);
  ]

let check (c : Config.t) ~path text =
  if Filename.check_suffix path ".mli" then
    let count = signature_lines text in
    if count > c.max_interface_lines then
      finding ~path ~count ~limit:c.max_interface_lines "signature lines"
    else []
  else if Filename.check_suffix path ".ml" then
    let count = raw_lines text in
    if count > c.max_file_lines then
      finding ~path ~count ~limit:c.max_file_lines "lines"
    else []
  else []
