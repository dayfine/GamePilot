let evolution_shows m =
  Battle_screen.battle_text_box m
  && (not (Battle_screen.hp_box m))
  && (not (Battle_screen.level_up_box m))
  && (not (Battle_text_arrow.advance_arrow m))
  && (not (Battle_yes_no.yes_no_box m))
  && not (Dark_corners.dark_corners m)
