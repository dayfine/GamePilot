type t = (string * string) list

let entry line =
  match String.index_opt line ' ' with
  | Some i when line <> "" && line.[0] <> '#' ->
      Some
        ( String.sub line 0 i,
          String.sub line (i + 1) (String.length line - i - 1) )
  | _ -> None

let of_string text = List.filter_map entry (String.split_on_char '\n' text)
let load path = of_string (In_channel.with_open_bin path In_channel.input_all)
