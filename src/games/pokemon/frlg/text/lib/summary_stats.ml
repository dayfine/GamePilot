(* Port of PokemonFRLG/Inference/PokemonFRLG_StatsReader.cpp using Frlg_text's
   font templates and Frlg_readers.Color_count for the gender icon. *)

module CC = Frlg_readers.Color_count

type gender = Male | Female | Genderless
type stats = { hp : int; atk : int; def : int; spa : int; spd : int; spe : int }

type layout = {
  game_w : float;
  game_h : float;
  digit_w : int;
  stat_ones_left : int;
  hp_top : int;
  stat_first_top : int;
  stat_pitch : int;
  max_stat_digits : int;
  gender_min_share : float;
  gender_timeout_ms : int;
}

let geom =
  {
    game_w = 240.;
    game_h = 160.;
    digit_w = 6;
    stat_ones_left = 230;
    hp_top = 19;
    stat_first_top = 37;
    stat_pitch = 13;
    max_stat_digits = 3;
    gender_min_share = 0.05;
    gender_timeout_ms = 1000;
  }

let nature_max_score = 0.02
let hp_max_score = 0.13
let stat_max_score = 0.08

(* First line of Page 1's TRAINER MEMO: capitals start at y=118 (glyph_top=115),
   left edge x=8, wide enough for "RELAXED nature." (~90 px). *)
let nature_line : Text_lines.t =
  { id = "summary_nature"; left = 8; indent = 0; glyph_top = 115; width = 104 }

let nature_names =
  [
    "HARDY";
    "LONELY";
    "BRAVE";
    "ADAMANT";
    "NAUGHTY";
    "BOLD";
    "DOCILE";
    "RELAXED";
    "IMPISH";
    "LAX";
    "TIMID";
    "HASTY";
    "SERIOUS";
    "JOLLY";
    "NAIVE";
    "MODEST";
    "MILD";
    "QUIET";
    "BASHFUL";
    "RASH";
    "CALM";
    "GENTLE";
    "SASSY";
    "CAREFUL";
    "QUIRKY";
  ]

let nature_candidates = List.map (fun s -> s ^ " nature.") nature_names

let nature_index_of_candidate text =
  let rec find i = function
    | [] -> None
    | c :: rest -> if c = text then Some i else find (i + 1) rest
  in
  find 0 nature_candidates

let stat_cell id ~glyph_top k : Text_lines.t =
  {
    id = Printf.sprintf "%s.%d" id k;
    left = geom.stat_ones_left - (geom.digit_w * k);
    indent = 0;
    glyph_top;
    width = geom.digit_w;
  }

let hp_digit k = stat_cell "summary_hp" ~glyph_top:geom.hp_top k

let stat_digit row k =
  let glyph_top = geom.stat_first_top + (geom.stat_pitch * row) in
  stat_cell (Printf.sprintf "summary_stat.%d" row) ~glyph_top k

let female_probe_id = "summary.gender.female"
let male_probe_id = "summary.gender.male"

type gender_rect = { gx : float; gy : float; gw : float; gh : float }

let gender_px = { gx = 103.; gy = 19.; gw = 11.; gh = 12. }

let gender_box : Wire.box =
  {
    x = gender_px.gx /. geom.game_w;
    y = gender_px.gy /. geom.game_h;
    w = gender_px.gw /. geom.game_w;
    h = gender_px.gh /. geom.game_h;
  }

let female_range : CC.range =
  { low = { r = 180; g = 0; b = 0 }; high = { r = 255; g = 130; b = 130 } }

let male_range : CC.range =
  { low = { r = 0; g = 0; b = 180 }; high = { r = 100; g = 160; b = 255 } }

let gender_probes =
  [
    CC.probe ~id:female_probe_id gender_box female_range;
    CC.probe ~id:male_probe_id gender_box male_range;
  ]

let gender_of_measurements m =
  match (CC.share m female_probe_id, CC.share m male_probe_id) with
  | Some female, Some male ->
      if female >= geom.gender_min_share && female > male then Some Female
      else if male >= geom.gender_min_share && male > female then Some Male
      else Some Genderless
  | _ -> None

let read_level = Summary_level.read

let read_nature glyphs =
  match
    Line_reading.read ~max_score:nature_max_score glyphs nature_line
      nature_candidates
  with
  | Line_reading.Read { text; _ } -> nature_index_of_candidate text
  | Line_reading.No_match _ -> None

let read_gender () =
  let ready m = Option.is_some (gender_of_measurements m) in
  Effects.with_probes gender_probes (fun () ->
      match Effects.await ~timeout_ms:geom.gender_timeout_ms ready with
      | Holds m -> gender_of_measurements m
      | Timeout -> None)

let hp_candidates = Number_reading.digits @ [ "/" ]

let read_hp glyphs =
  let rec from k =
    if k >= geom.max_stat_digits then []
    else
      match
        Line_reading.read ~max_score:hp_max_score glyphs (hp_digit k)
          hp_candidates
      with
      | Line_reading.Read { text; _ } when text <> "/" -> text :: from (k + 1)
      | _ -> []
  in
  match List.rev (from 0) with
  | [] -> None
  | ds -> int_of_string_opt (String.concat "" ds)

let read_number glyphs cell =
  Number_reading.read_right_aligned ~max_score:stat_max_score glyphs cell
    ~max_cells:geom.max_stat_digits

let read_stats glyphs =
  let ( let* ) = Option.bind in
  let* hp = read_hp glyphs in
  let* atk = read_number glyphs (stat_digit 0) in
  let* def = read_number glyphs (stat_digit 1) in
  let* spa = read_number glyphs (stat_digit 2) in
  let* spd = read_number glyphs (stat_digit 3) in
  let* spe = read_number glyphs (stat_digit 4) in
  Some { hp; atk; def; spa; spd; spe }
