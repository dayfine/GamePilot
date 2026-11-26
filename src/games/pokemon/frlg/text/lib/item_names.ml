type pocket = Items | Key_items | Poke_balls | Tm_case | Berry_pouch
type t = (pocket * string) list

let pocket_of_string = function
  | "items" -> Items
  | "key_items" -> Key_items
  | "poke_balls" -> Poke_balls
  | "tm_case" -> Tm_case
  | "berry_pouch" -> Berry_pouch
  | s -> failwith ("item pocket " ^ s)

let split_entry line =
  match String.index_opt line ' ' with
  | Some i ->
      ( pocket_of_string (String.sub line 0 i),
        String.sub line (i + 1) (String.length line - i - 1) )
  | None -> failwith ("item line " ^ line)

let entry line =
  if line = "" || line.[0] = '#' then None else Some (split_entry line)

let of_string text = List.filter_map entry (String.split_on_char '\n' text)
let load path = of_string (In_channel.with_open_bin path In_channel.input_all)

let in_pocket t pocket =
  List.filter_map (fun (p, name) -> if p = pocket then Some name else None) t
