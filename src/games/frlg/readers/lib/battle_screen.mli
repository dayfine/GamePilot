(** Readers: a battle on screen. Ported from the fork's
    Inference/PokemonFRLG_BattleTextBoxDetector (the text box),
    Dialogs/PokemonFRLG_BattleDialogs (BattleMenuDetector: the FIGHT / BAG /
    POKEMON / RUN menu) and PokemonFRLG_BattlePokemonDetector (the two HP
    boxes), and BattleLevelUpDetector; the boxes are theirs, relative to the
    game picture, unless a reader says otherwise.

    The battle text box is dark teal with a white line and a gold band above it.
    The menu is a white box on the right of a shorter teal box. *)

val probes : Wire.probe_spec list
(** Every probe the readers need. *)

val teal_box : Effects.measurements -> string -> bool
(** The probe with this id ({!Solid_color.probe}) shows the text box's flat
    teal, as the fork tests it. *)

(** {1 Readers} *)

val battle_text_box : Effects.measurements -> bool
(** The full-width teal text box, with its white line and gold band: a battle's
    opening and its messages. *)

val battle_menu : Effects.measurements -> bool
(** The action menu beside a short teal box (any language; Japanese has its own
    boxes). The Safari Zone's BALL / BAIT / ROCK / RUN menu is the same box. *)

val player_box : Effects.measurements -> bool
(** The player's HP box (bottom right): gone once the player's battler fainted.
*)

val foe_box : Effects.measurements -> bool
(** The foe's HP box (top left). *)

val hp_box : Effects.measurements -> bool
(** The player's or the foe's HP box, on a battle background that is neither
    white nor the sand of a battle in a cave. *)

val move_menu : Effects.measurements -> bool
(** The move menu: a white moves box and a white PP box with the dark frame
    between them. Not in the fork (its move cursor reader needs waterfill);
    measured on mGBA frames, singles and doubles. *)

val level_up_box : Effects.measurements -> bool
(** The stats box after a level up, which covers the text box's right end
    (BattleLevelUpDetector, either page). *)

val battle_shows : Effects.measurements -> bool
(** Any of the readers above: what the settle rule counts as a battle. *)
