let fold f text =
  let rec go pos acc =
    if pos >= String.length text then List.rev acc
    else
      let d = String.get_utf_8_uchar text pos in
      let n = Uchar.utf_decode_length d in
      go (pos + n) (f text pos n d :: acc)
  in
  go 0 []

let chars = fold (fun text pos n _ -> String.sub text pos n)
let uchars = fold (fun _ _ _ d -> Uchar.utf_decode_uchar d)
