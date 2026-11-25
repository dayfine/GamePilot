let is_letter c = c >= 'a' && c <= 'z'
let is_digit c = c >= '0' && c <= '9'

(* The id without its trailing letters, and the letters; ["cp-05a"] is
   ("cp-05", "a"). Letters count only after a digit. *)
let split id =
  let rec start i =
    if i > 0 && is_letter id.[i - 1] then start (i - 1) else i
  in
  let i = start (String.length id) in
  if i < String.length id && i > 0 && is_digit id.[i - 1] then
    (String.sub id 0 i, String.sub id i (String.length id - i))
  else (id, "")

(* The bare id sorts after its lettered parts. *)
let part_key = function "" -> None | letters -> Some letters

let compare a b =
  let base_a, part_a = split a and base_b, part_b = split b in
  match String.compare base_a base_b with
  | 0 -> (
      match (part_key part_a, part_key part_b) with
      | None, None -> 0
      | None, Some _ -> 1
      | Some _, None -> -1
      | Some x, Some y -> String.compare x y)
  | c -> c
