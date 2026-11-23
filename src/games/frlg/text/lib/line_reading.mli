(** Reads one line of FRLG text by drawing each candidate in the game's font and
    scoring it with [core.template_match@1] over the line's box: the
    best-scoring candidate is the text, unless even it scores above
    {!max_score}. No OCR: a line can only read as one of its candidates, so a
    caller keeps them few (a bag row: the open pocket's names). *)

type reading =
  | Read of { text : string; score : float }
  | No_match of { best : string option; score : float }
      (** the line shows none of the candidates (blank row, another screen) *)

val max_score : float
(** The highest [score] a match may have. On Switch captures right reads score
    0.0018-0.0086 (the bag's last row is the worst), while the best candidate on
    a line without one of them scores 0.011 or more (a blank row, the TM case's
    CLOSE, a registered item drawn in blue). A word the line shows that is
    missing from the candidates can still read as a near one (the mart's POKé
    BALL as POKé DOLL, 0.0056): candidates must cover the line. *)

val template :
  Glyph_table.t -> Text_lines.t -> string -> (string, string) result
(** The candidate drawn as the line shows it, as PNG bytes for
    [probe.upload_template]: {!Text_lines.template_height} rows, the line's full
    width. *)

val probe_id : Text_lines.t -> string -> string
(** ["<line id>/<candidate>"]. *)

val probe : Text_lines.t -> string -> template:string -> Wire.probe_spec
(** The candidate's [core.template_match@1] probe over the line's box, [Latest]
    delivery. [template] is the upload's hash (or, for the offline
    [probe_images] tool, the PNG's path). *)

val pick : Text_lines.t -> string list -> Effects.measurements -> reading
(** The best candidate among those with a result in the frame. *)

val read : Glyph_table.t -> Text_lines.t -> string list -> reading
(** Uploads one template per candidate (the handler sends each distinct PNG once
    per connection), subscribes one probe per candidate, and picks from the
    first frame that has them all. Raises [Invalid_argument] if a candidate
    cannot be drawn on the line, and [Failure] if no such frame comes within a
    second. *)
