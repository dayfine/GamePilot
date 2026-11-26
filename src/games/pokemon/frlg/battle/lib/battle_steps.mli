(** The {!Battle.game_steps} that play FireRed: it presses buttons and reads the
    screen through the effects only, so it runs live and on a replayed log
    alike. The caller subscribes {!Battle_look.probes} first.

    Every press sequence starts from a known place: a menu's cursor is pushed
    into a corner before it moves ({!Battle_cursor}), the party list in battle
    opens on slot 0 and the move list to forget from on its top move
    (pokefirered party_menu.c, battle_script_commands.c), and the next step
    waits for the screen to show the press worked.

    The readers it acts on: the battle's YES/NO box ({!Battle.Move_learn} with
    the player's HP box up, {!Battle.Use_next} without), the move menu's PP in
    red ({!Battle.Refused} before A), the battle text's arrow (B only then; see
    {!Event_rule}), what an evolution shows (never B), the party list in either
    layout, and the move list's cursor (A only on the move to forget).
    Unverified for want of captures: the PP reader at 0 PP, the evolution
    screen, the double battle's party list. A trainer's "Will ... change
    POKéMON?" (the Shift battle style) looks like a move to learn
    ({!Battle.Switch_offer}); [is_switch_offer] tells them apart. *)

val make :
  ?read_move_name:(Effects.measurements -> slot:int -> string option) ->
  ?read_offered_move:(unit -> string option) ->
  ?is_switch_offer:(unit -> bool) ->
  unit ->
  Battle.game_steps
(** [read_move_name] reads a move's name off the open move menu; without it a
    script's move names are not checked. The move-name reader of the FRLG text
    work plugs in here. [read_offered_move] reads the slug of the move offered
    on the open list to forget from (its fifth row); without it a [Forget_for]
    answer finds the move unread. [is_switch_offer] reads whether the YES/NO up
    is a trainer's switch offer, not a move learn; without it every such YES/NO
    is a move learn, as the fork's farmers find with the Set style. *)
