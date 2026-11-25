(** Base64 (RFC 4648, standard alphabet, padded): how template PNG bytes travel
    in [probe.upload_template]. *)

val encode : string -> string
(** The padded standard base64 of these bytes. *)

val decode : string -> string option
(** [None] unless the text is padded standard base64. *)
