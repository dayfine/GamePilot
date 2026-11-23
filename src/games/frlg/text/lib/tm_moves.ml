type t = (string * string) list

let split_entry line =
  match String.index_opt line ' ' with
  | Some i ->
      (String.sub line 0 i, String.sub line (i + 1) (String.length line - i - 1))
  | None -> failwith ("TM move line " ^ line)

let entry line =
  if line = "" || line.[0] = '#' then None else Some (split_entry line)

let of_string text = List.filter_map entry (String.split_on_char '\n' text)
let load path = of_string (In_channel.with_open_bin path In_channel.input_all)
let names t = List.map snd t
