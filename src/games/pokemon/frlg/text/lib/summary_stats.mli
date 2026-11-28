(** Summary Page 1 (level, nature, gender) and Page 2 (HP, Attack, Defense, Sp.
    Atk, Sp. Def, Speed) readers.

    Port of [PokemonFRLG/Inference/PokemonFRLG_StatsReader.cpp]
    (https://github.com/PokemonAutomation/Arduino-Source) using {!Frlg_text}'s
    font templates ({!Line_reading}, {!Number_reading}, {!Summary_level}) and
    {!Frlg_readers.Color_count} probes for the Page 1 gender icon. *)

(** Gender shown by the Page 1 header icon. *)
type gender =
  | Male  (** Blue male icon. *)
  | Female  (** Red/orange female icon. *)
  | Genderless  (** Neither icon shown. *)

type stats = {
  hp : int;  (** Max Hit Points (the number after ['/'] on Page 2). *)
  atk : int;  (** Attack. *)
  def : int;  (** Defense. *)
  spa : int;  (** Special Attack. *)
  spd : int;  (** Special Defense. *)
  spe : int;  (** Speed. *)
}
(** Six stats read from Summary Page 2 ([POKéMON SKILLS]). *)

val nature_line : Text_lines.t
(** The first line of Page 1's [TRAINER MEMO] box (e.g. ["CALM nature."]). *)

val nature_candidates : string list
(** The 25 English candidate strings (["HARDY nature."] .. ["QUIRKY nature."])
    in Gen 3 nature order (0..24). *)

val nature_index_of_candidate : string -> int option
(** Maps a matched candidate string from {!nature_candidates} back to its Gen 3
    nature index [0..24]. *)

val nature_max_score : float
(** Maximum template-match score for {!nature_line}. *)

val hp_max_score : float
(** Maximum template-match score for each Page 2 max-HP digit cell (higher than
    {!stat_max_score} because the HP bar's dark top border sits on row 11 of the
    12-row template). *)

val stat_max_score : float
(** Maximum template-match score for each Page 2 non-HP stat digit cell. *)

val hp_candidates : string list
(** Digits ["0".."9"] plus ["/"], so right-aligned max-HP reading stops cleanly
    at the slash separating current and max HP. *)

val hp_digit : int -> Text_lines.t
(** Right-aligned digit cell [k] ([0] = ones, [1] = tens, [2] = hundreds) of
    Page 2's max HP number. *)

val stat_digit : int -> int -> Text_lines.t
(** Right-aligned digit cell [k] ([0..2]) of Page 2's non-HP stat row [row] ([0]
    = Attack, [1] = Defense, [2] = Sp. Atk, [3] = Sp. Def, [4] = Speed). *)

val gender_probes : Wire.probe_spec list
(** The two [core.color_count@1] probes over the Page 1 gender icon box
    (red/orange for Female, blue for Male). *)

val gender_of_measurements : Effects.measurements -> gender option
(** Classifies {!gender} from a frame carrying {!gender_probes}, or [None] when
    either probe is absent. *)

val read_level : Glyph_table.t -> int option
(** Reads the level on the open Summary page ({!Summary_level.read}). *)

val read_nature : Glyph_table.t -> int option
(** Reads the Gen 3 nature index [0..24] from Page 1's [TRAINER MEMO] line.
    English only; non-English saves need localized nature strings. *)

val read_gender : unit -> gender option
(** Reads the Page 1 gender icon from the current frame, or [None] on timeout.
*)

val read_stats : Glyph_table.t -> stats option
(** Reads all 6 stats from Page 2 ([POKéMON SKILLS]), returning [None] if any
    stat fails to read. *)
