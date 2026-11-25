(** Output of the daemon's offline [probe_images] tool: one line
    [{"image": path, "probes": {id: result}}] per image, the [probes] of a
    [frame] notification. *)

type json = Yojson.Safe.t
(** A decoded JSON value: one line of the tool's output. *)

type image_probes = string * (string * Probe.probe_result) list
(** The image's path as the tool printed it, and its probe results by id. *)

val image_probes_of_json : json -> image_probes
(** One line's image and probes; a line without them is a [Decode_error]. *)

val image_probes_of_string : string -> image_probes list
(** One result per non-blank line, in file order. *)

val read_image_probes : string -> image_probes list
(** Reads the tool's output file at this path. *)
