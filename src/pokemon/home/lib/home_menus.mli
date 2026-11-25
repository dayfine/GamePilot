(** Reader: Pokémon HOME's screens before and after the boxes, on the whole
    1080p frame (Traditional Chinese UI on console B), measured on console B's
    captures of 2026-11-24 (the BDSP banking run, [test/images]).

    - The main menu (主選單): its orange 寶可夢 button fills over 0.45 of (1075, 238,
      653, 130) (red over 210, green 121 to 204, blue under 60), as
      [plza_claim_and_bank.sh]'s [home_menu] test in the BDSPLab lab tools read
      it: 0.67 on the menu, 0.03 at most elsewhere.
    - The bottom banner (logging in, saving, saved): a white strip along its top
      (307, 864, 1306, 22), and whether each of its two text lines (288, 896,
      864, 49) and (288, 967, 864, 54) holds text (stddevs summing to 60 or
      more; a blank line reads 0, a line of text 136 at least). The script read
      the banner as a white bar and could not tell saving from saved; here
      "saving" (正在儲存紀錄……/請勿關閉) is two lines and "saved" (已確實儲存紀錄了！) is taken to
      be one. No capture of the saved banner survives: that is a guess.
    - The game list (請選擇要連動的遊戲軟體): a 3x3 grid of 194 px tiles from (1046, 344),
      267 across and 222 down. The page is light above the game's card ((100,
      200, 800, 40): means summing to 400 or more, stddevs to 30 or less); the
      cursor's tile has the orange frame along its top (1.00 of the strip; 0.00
      on the others), and a game's tile shows its icon (a
      [core.template_match@1] probe per tile, the icon's middle 134 px). *)

val probes : game_icon:Effects.template_hash -> Wire.probe_spec list
(** Every probe, with the game's icon template for the game list. *)

val main_menu : Effects.measurements -> bool
(** The main menu shows: its orange button fills over 0.45 of its box. *)

(** The bottom banner. *)
type banner =
  | No_banner  (** no white bar along the bottom *)
  | Blank  (** the white bar, no text (between login lines) *)
  | One_line  (** text on the first line only: taken to be "saved" *)
  | Two_lines  (** "logging in" or "saving" *)

val banner : Effects.measurements -> banner
(** The banner the frame shows. *)

val banner_to_string : banner -> string
(** "no banner", "a one-line banner", ...: for a log line. *)

type tile = { row : int; col : int }
(** A tile of the game list, 0-based from the top left. *)

val cursor_tile : Effects.measurements -> tile option
(** The tile with the orange frame: the game list shows. *)

val game_tile : Effects.measurements -> tile option
(** The first tile whose icon scores {!max_icon_score} or less. *)

val max_icon_score : float
(** 0.05. *)

val icon_scores : Effects.measurements -> float list
(** Each tile's icon score, row by row, for a log line (1 for a missing probe).
*)
