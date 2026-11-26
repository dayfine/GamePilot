module N = Frlg_readers.Naming_screen

type position = { page : N.page; key : N.key }

(* sKeyboardChars, each row padded with spaces to the page's columns. *)
let grid = function
  | N.Upper -> [ "ABCDEF ."; "GHIJKL ,"; "MNOPQRS "; "TUVWXYZ " ]
  | N.Lower -> [ "abcdef ."; "ghijkl ,"; "mnopqrs "; "tuvwxyz " ]
  | N.Others -> [ "01234 "; "56789 "; "!?♂♀/-"; "…“”‘' " ]

let rows page =
  List.map (fun r -> Array.of_list (Strings.Utf8.chars r)) (grid page)

let char_at page (k : N.key) = (List.nth (rows page) k.row).(k.col)
let space = " "

let page_chars page =
  let all = List.concat_map Array.to_list (rows page) in
  let distinct =
    List.fold_left
      (fun acc c -> if List.mem c acc then acc else c :: acc)
      [] all
  in
  List.filter (fun c -> c <> space) (List.rev distinct) @ [ space ]

let pages = [ N.Upper; N.Lower; N.Others ]

let charset =
  List.fold_left
    (fun acc page ->
      acc @ List.filter (fun c -> not (List.mem c acc)) (page_chars page))
    [] pages
  |> List.filter (fun c -> c <> space)
  |> fun l -> l @ [ space ]

let keys_of page =
  List.concat
    (List.mapi
       (fun row cells ->
         List.mapi (fun col c -> ({ N.row; col }, c)) (Array.to_list cells))
       (rows page))

let key_on page c =
  List.find_map
    (fun (key, x) -> if x = c then Some { page; key } else None)
    (keys_of page)

let find ~on c =
  match key_on on c with
  | Some p -> Some p
  | None -> List.find_map (fun page -> key_on page c) pages

let chars text =
  let cs = Strings.Utf8.chars text in
  match List.find_opt (fun c -> not (List.mem c charset)) cs with
  | Some c -> Error (Printf.sprintf "the keyboard has no \"%s\"" c)
  | None -> Ok cs

let next_page = function
  | N.Upper -> N.Lower
  | N.Lower -> N.Others
  | N.Others -> N.Upper
