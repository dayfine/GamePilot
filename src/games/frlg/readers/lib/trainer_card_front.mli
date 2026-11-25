(** Reader: the Trainer Card's front (Start menu, the player's name), its eight
    badge slots and its stars. New, as the fork reads no badges.

    Laid out as pret pokefirered's [src/trainer_card.c] draws it: the card on
    BG0 from its front tilemap, then [DrawStarsAndBadgesOnCard] on BG3. Badge
    [i] (from 0, FLAG_BADGE01_GET + i) is a 16 by 16 tile block at x = 32 + 24
    i, y = 128 when earned; an empty slot shows the card's own number. In
    FireRed the badges are on the front, not the back. The stars are 8 by 8
    tiles at x = 120 + 8 k, y = 56, as many as the card's star count (its color
    goes blue, green, bronze, silver, gold with it). For the player's own card
    ([TrainerCard_GenerateCardForLinkPlayer]) the first star is the Hall of Fame
    ([GAME_STAT_ENTERED_HOF]); the others are the Kanto dex with Mewtwo, the
    National dex, and the two wireless minigames' 200 records, none of which a
    save gets before the Hall of Fame but the last.

    Thresholds come from renders of pret's graphics (palettes as mGBA shows
    them), which match the lab's mGBA frame of the card with no badge and no
    star to the pixel; real mGBA frames of a post-League save (8 badges, 1 star)
    read as such, and so do real Switch frames of the same save (console B's
    capture card). *)

val probes : Wire.probe_spec list
(** Every probe {!front_shown} and {!read} need. *)

val badge_names : string list
(** The eight badges in slot order, as plans name them: ["boulder"],
    ["cascade"], ["thunder"], ["rainbow"], ["soul"], ["marsh"], ["volcano"],
    ["earth"]. *)

type t = {
  badges : bool list;  (** Each slot earned, in {!badge_names}' order. *)
  stars : int;  (** 0 to 4. *)
}

val earned : t -> string list
(** The earned badges' names. *)

val hall_of_fame : t -> bool
(** At least one star: the Hall of Fame entered. *)

val to_string : t -> string
(** ["3 badges (boulder, cascade, thunder), no star"]. *)

(** {1 Thresholds} *)

val min_body_channel : float
(** The card's body above the money row (x 24 to 111, y 56 to 63), striped white
    and the card's palest tint: each channel's mean from this (pret renders: 230
    at the lowest; a fading card is darker)... *)

val max_body_stddev_sum : float
(** ...and the channels' stddev summed at most this (36.5 on the bronze card).
*)

val min_strip_sum : float
(** The BADGES strip left of the first slot (x 12 to 27, y 130 to 141), in the
    card's color: channel sum from this (527 on the gold card)... *)

val max_strip_sum : float
(** ...to this (643 on the silver card; 689 and 700 on two mGBA frames of white
    menus over the overworld). *)

val min_body_over_strip : float
(** The body's channel sum above the strip's by at least this (106 on the silver
    card, the closest; 45 on the nearest frame that is not the card). *)

val max_strip_stddev_sum : float
(** Its stddev summed at most this (46.7 on the gold card). *)

val dark_max : int
(** A badge's outline: each channel at most this. No empty slot has such a pixel
    on any card color. *)

val min_badge_share : float
(** An earned slot: dark pixels in its middle 12 by 12 at least this share (the
    Boulder Badge has 0.11, the fewest). *)

val min_star_share : float
(** A star: its tile's pixels in the star's yellow ((255, 214, 82) on mGBA) at
    least this share (23 of 64 pixels when drawn). *)

(** {1 Reader} *)

val front_shown : Effects.measurements -> bool
(** The card's front, faded in: its body white and its BADGES strip in the
    card's color. *)

val read : Effects.measurements -> t option
(** The badges and stars; [None] unless {!front_shown}. *)
