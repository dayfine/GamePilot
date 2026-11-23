(** The {!Battle_driver} that plays FireRed: it presses buttons and reads the
    screen through the effects only, so it runs live and on a replayed log
    alike. The caller subscribes {!Battle_look.probes} first.

    Every press sequence starts from a known place: a menu's cursor is pushed
    into a corner before it moves ({!Battle_cursor}), the party list in battle
    opens on slot 0 and the move list to forget from on its top move
    (pokefirered party_menu.c, battle_script_commands.c), and the next step
    waits for the screen to show the press worked.

    The readers it acts on: the battle's YES/NO box ({!Battle_driver.Move_learn}
    with the player's HP box up, {!Battle_driver.Use_next} without), the move
    menu's PP in red ({!Battle_driver.Refused} before A), the battle text's
    arrow (B only then; see {!Event_rule}), what an evolution shows (never B),
    the party list in either layout, and the move list's cursor (A only on the
    move to forget). Unverified for want of captures: the PP reader at 0 PP, the
    evolution screen, the double battle's party list. A trainer's "Will ...
    change POKéMON?" (the Shift battle style) reads as a move to learn: the
    fork's lab plays with the Set style. *)

val make :
  ?read_move_name:(Effects.measurements -> slot:int -> string option) ->
  ?read_offered_move:(unit -> string option) ->
  unit ->
  Battle_driver.t
(** [read_move_name] reads a move's name off the open move menu; without it a
    script's move names are not checked. The move-name reader of the FRLG text
    work plugs in here. [read_offered_move] reads the slug of the move offered
    on the open list to forget from (its fifth row); without it a [Forget_for]
    answer finds the move unread. *)
