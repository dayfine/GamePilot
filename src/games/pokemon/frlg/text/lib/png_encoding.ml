let signature = "\137PNG\r\n\026\n"
let bit_depth = 8
let color_type_rgb = 2
let filter_none = 0
let max_stored_block = 65535
let adler_modulus = 65521
let crc_polynomial = 0xEDB88320
let byte_values = 256
let byte_mask = 0xFF
let crc_bits = 0xFFFFFFFF
let block_length_mask = 0xFFFF
let adler_high_shift = 16
let zlib_overhead = 64
let zlib_header = "\x78\x01" (* deflate, 32K window, no preset dictionary *)

let crc_table =
  Array.init byte_values (fun n ->
      let c = ref n in
      for _ = 1 to 8 do
        c := if !c land 1 = 1 then crc_polynomial lxor (!c lsr 1) else !c lsr 1
      done;
      !c)

let crc32 s =
  let c = ref crc_bits in
  String.iter
    (fun ch ->
      c := crc_table.(!c lxor Char.code ch land byte_mask) lxor (!c lsr 8))
    s;
  !c lxor crc_bits

let adler32 s =
  let a = ref 1 and b = ref 0 in
  String.iter
    (fun ch ->
      a := (!a + Char.code ch) mod adler_modulus;
      b := (!b + !a) mod adler_modulus)
    s;
  (!b lsl adler_high_shift) lor !a

let be32 n =
  let b = Bytes.create 4 in
  Bytes.set_int32_be b 0 (Int32.of_int n);
  Bytes.to_string b

let chunk kind data =
  be32 (String.length data) ^ kind ^ data ^ be32 (crc32 (kind ^ data))

(* One deflate stored block: final flag, length and its complement (LE). *)
let stored_block ~final data =
  let len = String.length data in
  let header = Bytes.create 5 in
  Bytes.set_uint8 header 0 (if final then 1 else 0);
  Bytes.set_uint16_le header 1 len;
  Bytes.set_uint16_le header 3 (len lxor block_length_mask);
  Bytes.to_string header ^ data

let zlib_stored data =
  let buf = Buffer.create (String.length data + zlib_overhead) in
  Buffer.add_string buf zlib_header;
  let len = String.length data in
  let rec blocks pos =
    let n = min max_stored_block (len - pos) in
    let final = pos + n >= len in
    Buffer.add_string buf (stored_block ~final (String.sub data pos n));
    if not final then blocks (pos + n)
  in
  blocks 0;
  Buffer.add_string buf (be32 (adler32 data));
  Buffer.contents buf

let scanlines (image : Text_drawing.image) =
  let row = image.width * 3 in
  let buf = Buffer.create ((row + 1) * image.height) in
  for y = 0 to image.height - 1 do
    Buffer.add_uint8 buf filter_none;
    Buffer.add_subbytes buf image.pixels (y * row) row
  done;
  Buffer.contents buf

(* Width, height, then bit depth, color type and three zero bytes: deflate
   compression, adaptive filtering, no interlace. *)
let header (image : Text_drawing.image) =
  let tail = Bytes.make 5 '\000' in
  Bytes.set_uint8 tail 0 bit_depth;
  Bytes.set_uint8 tail 1 color_type_rgb;
  be32 image.width ^ be32 image.height ^ Bytes.to_string tail

let encode_rgb (image : Text_drawing.image) =
  let ihdr = header image in
  signature ^ chunk "IHDR" ihdr
  ^ chunk "IDAT" (zlib_stored (scanlines image))
  ^ chunk "IEND" ""
