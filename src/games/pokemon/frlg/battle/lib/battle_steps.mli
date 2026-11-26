(** The {!Battle.game_steps} that play FireRed: it presses buttons and reads the
    screen through the effects only, so it runs live and on a replayed log
    alike. The caller subscribes {!Battle_look.probes} first.

    Every press sequence starts from a known place: a menu's cursor is pushed
    into a corner before it moves ({!Battle_cursor}), the party list in battle
    opens on slot 0 (pokefirered party_menu.c), and the next step waits for the
    screen to show the press worked.

    The readers it acts on: the battle's YES/NO box ({!Battle.Move_learn} with
    the player's HP box up, {!Battle.Use_next} without), the move menu's PP in
    red ({!Battle.Refused} before A), the battle text's arrow (B only then; see
    {!Event_rule}), the level-up stats box ({!Battle.Level_up}) and
    post-level-up evolution screen ({!Battle.Evolution}), and the party list in
    either layout. Level-ups, move learns and evolutions go through
    {!Battle_level_up_steps}. Unverified for want of captures: the PP reader at
    0 PP, the evolution screen, the double battle's party list. A trainer's
    "Will ... change POKéMON?" (the Shift battle style) looks like a move to
    learn ({!Battle.Switch_offer}); [is_switch_offer] tells them apart. *)

val make :
  ?read_move_name:(Effects.measurements -> slot:int -> string option) ->
  ?read_forget_list:(unit -> Level_up.forget_list) ->
  ?is_switch_offer:(unit -> bool) ->
  ?log:(string -> unit) ->
  unit ->
  Battle.game_steps
(** [read_move_name] reads a move's name off the open move menu; without it a
    script's move names are not checked. The move-name reader of the FRLG text
    work plugs in here. [read_forget_list] reads the move offered and known
    moves on the open list to forget from for {!Battle_level_up_steps}; without
    it the list reads empty. [is_switch_offer] reads whether the YES/NO up is a
    trainer's switch offer, not a move learn; without it every such YES/NO is a
    move learn, as the fork's farmers find with the Set style. *)
