(** The battle's {!Level_up.game_steps}: it reads battle level-up screens
    ({!Level_up_screens}) and presses buttons through effects only, while
    {!Level_up} makes every decision (which moves to learn or decline, and
    whether each evolution runs or is cancelled with B).

    Text during level-ups and evolutions is pressed with A, never B, so an
    evolution is never cancelled by mistake. {!Level_up.Back} is either a
    returning battle screen (the action menu or forced switch-in party list, or
    a trainer's switch offer YES/NO) or no battle screen for
    {!Event_rule.over_after_ms} (the overworld after the battle ends). *)

val battle : Level_up_screens.context
(** The battle's screens: its stats window ({!Frlg_readers.Battle_screen}), its
    YES/NO box ({!Frlg_readers.Battle_yes_no}), and the action menu or party
    list where a mid-battle level-up returns. *)

val make :
  ?read_forget_list:(unit -> Level_up.forget_list) ->
  ?is_switch_offer:(unit -> bool) ->
  ?log:(string -> unit) ->
  unit ->
  Level_up.game_steps
(** [read_forget_list] reads the offered move and known moves off the open list
    to forget from; without it the list reads empty. [is_switch_offer] tells a
    trainer's "Will ... change POKéMON?" apart from a move learn YES/NO,
    reporting {!Level_up.Back} so the battle answers it. *)
