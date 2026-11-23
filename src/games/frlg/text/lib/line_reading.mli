(** Reads one line of FRLG text by drawing each candidate in the game's font and
    scoring it with [core.template_match@1] over the line's box: the
    best-scoring candidate is the text, unless even it scores above
    {!max_score}. The probes compare masks ({!ink}), so the text's color does
    not matter. No OCR: a line can only read as one of its candidates, so a
    caller keeps them few (a bag row: the open pocket's names; a TM case row:
    the TM and HM moves). *)

type reading =
  | Read of { text : string; score : float }
  | No_match of { best : string option; score : float }
      (** the line shows none of the candidates (blank row, another screen) *)

val ink : Wire.color_range
(** Dark text: red and green 0..144, any blue. That holds the list windows' gray
    (99, 99, 99), the summary's near-black (33) and a registered item's blue
    (about 40, 88, 240), and leaves out their shadows (214 gray; 156, 200, 248
    under blue), the window backgrounds and the summary's teal. Measured on
    Switch captures and mGBA frames. *)

val max_score : float
(** The highest [score] (fraction of differing mask pixels) a match may have.
    Right reads score up to 0.0153 on Switch captures (seams of the 6.5x scale)
    and 0 on mGBA, but 0.0128 where the bag's scroll arrow covers a name; the
    best candidate on a line without one of them scores 0.034 or more (a blank
    row, the TM case's CLOSE). A word the line shows that is missing from the
    candidates can still read as a near one: candidates must cover the line. *)

val light_ink : Wire.color_range
(** White text: every channel 200..255. The battle's messages are white on its
    teal box (41, 82, 107), with a dark shadow; measured on mGBA frames. *)

val template :
  ?ink:Wire.color_range ->
  Glyph_table.t ->
  Text_lines.t ->
  string ->
  (string, string) result
(** The candidate's mask drawn where the line shows it, as PNG bytes for
    [probe.upload_template]: {!Text_lines.template_height} rows, the line's full
    width. The daemon masks the template with the probe's [ink] (default {!ink})
    as it masks the screen, so the text is drawn in it: black on white, or white
    on black for {!light_ink}. *)

val probe_id : Text_lines.t -> string -> string
(** ["<line id>/<candidate>"]. *)

val probe :
  ?ink:Wire.color_range ->
  Text_lines.t ->
  string ->
  template:string ->
  Wire.probe_spec
(** The candidate's [core.template_match@1] probe with [ink] (default {!ink})
    over the line's box, [Latest] delivery. [template] is the upload's hash (or,
    for the offline [probe_images] tool, the PNG's path). *)

val pick : Text_lines.t -> string list -> Effects.measurements -> reading
(** The best candidate among those with a result in the frame. *)

val probes :
  ?ink:Wire.color_range ->
  Glyph_table.t ->
  Text_lines.t ->
  string list ->
  Wire.probe_spec list
(** One probe per candidate, its template uploaded (the handler sends each
    distinct PNG once per connection); the caller subscribes them and {!pick}s.
    Raises [Invalid_argument] if a candidate cannot be drawn on the line. *)

val read : Glyph_table.t -> Text_lines.t -> string list -> reading
(** Uploads one template per candidate (the handler sends each distinct PNG once
    per connection), subscribes one probe per candidate, picks from the first
    frame that has them all, and unsubscribes them. Raises [Invalid_argument] if
    a candidate cannot be drawn on the line, and [Failure] if no such frame
    comes within a second. *)
