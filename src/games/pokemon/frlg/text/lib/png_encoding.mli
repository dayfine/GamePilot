(** Encodes an 8-bit RGB image as a PNG file, stdlib only: the zlib stream uses
    stored (uncompressed) deflate blocks, which every decoder reads. Text
    templates are a few kilobytes, so compression would not pay for its code. *)

val encode_rgb : Text_drawing.image -> string
(** The PNG file's bytes. *)
