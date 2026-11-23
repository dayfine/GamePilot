(** The {!Battle_driver} that plays FireRed: it presses buttons and reads the
    screen through the effects only, so it runs live and on a replayed log
    alike. The caller subscribes {!Battle_look.probes} first.

    Every press sequence starts from a known place: a menu's cursor is pushed
    into a corner before it moves ({!Battle_cursor}), the party list in battle
    opens on slot 0 and the move list to forget from on its top move
    (pokefirered party_menu.c, battle_script_commands.c), and the next step
    waits for the screen to show the press worked.

    Not read yet, for want of readers: the battle's YES/NO box (so
    {!Battle_driver.Move_learn} and {!Battle_driver.Use_next} never come; see
    {!Battle_look.of_measurements}), "no PP left" (so a move is never
    {!Battle_driver.Refused}: the action menu comes back and asks again), and an
    evolution after the battle, which a B on its text cancels. The party list
    reader knows a single battle's layout; a double battle's list (two big
    boxes) is not checked by slot and may not read as the party list at all
    until a capture of one says. *)

val make :
  ?read_move_name:(Effects.measurements -> slot:int -> string option) ->
  unit ->
  Battle_driver.t
(** [read_move_name] reads a move's name off the open move menu; without it a
    script's move names are not checked. The move-name reader of the FRLG text
    work plugs in here. *)
