let alphabet =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

let bits_per_char = 6
let bits_per_byte = 8
let chars_per_group = 4
let bytes_per_group = 3
let byte_mask = 0xff
let char_mask = 0x3f

(* [n] bytes from [s] at [pos] as one big-endian integer, zero-padded to a
   whole group. *)
let group_bits s pos n =
  let byte i = if i < n then Char.code s.[pos + i] else 0 in
  List.fold_left
    (fun acc i -> (acc lsl bits_per_byte) lor byte i)
    0
    (List.init bytes_per_group Fun.id)

let encode s =
  let out = Buffer.create ((String.length s + 2) / 3 * chars_per_group) in
  let rec go pos =
    let n = min bytes_per_group (String.length s - pos) in
    if n > 0 then (
      let bits = group_bits s pos n in
      for i = 0 to chars_per_group - 1 do
        let shift = (chars_per_group - 1 - i) * bits_per_char in
        Buffer.add_char out
          (if i <= n then alphabet.[(bits lsr shift) land char_mask] else '=')
      done;
      go (pos + n))
  in
  go 0;
  Buffer.contents out

let sextet ch = String.index_opt alphabet ch

(* Trailing '=' count of the last group; other groups have none. *)
let padding text pos =
  let last = pos + chars_per_group = String.length text in
  if not last then 0
  else if text.[pos + 3] <> '=' then 0
  else if text.[pos + 2] <> '=' then 1
  else 2

let decode_group text pos out =
  let pad = padding text pos in
  let kept = chars_per_group - pad in
  let rec bits i acc =
    if i = chars_per_group then Some acc
    else
      let value = if i < kept then sextet text.[pos + i] else Some 0 in
      Option.bind value (fun v -> bits (i + 1) ((acc lsl bits_per_char) lor v))
  in
  bits 0 0
  |> Option.map (fun b ->
         for i = 0 to bytes_per_group - 1 - pad do
           let shift = (bytes_per_group - 1 - i) * bits_per_byte in
           Buffer.add_char out (Char.chr ((b lsr shift) land byte_mask))
         done)

(* Decodes the groups from [pos] on into [out]. *)
let rec decode_from text pos out =
  if pos = String.length text then Some (Buffer.contents out)
  else
    Option.bind (decode_group text pos out) (fun () ->
        decode_from text (pos + chars_per_group) out)

let decode text =
  let len = String.length text in
  if len mod chars_per_group <> 0 then None
  else
    decode_from text 0 (Buffer.create (len / chars_per_group * bytes_per_group))
