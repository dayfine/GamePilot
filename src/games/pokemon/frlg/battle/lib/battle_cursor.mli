(** Where the battle's cursors go: the presses that reach an action, a move or a
    target from wherever the cursor was. Pure.

    The action menu and the move menu are 2x2 grids that stop at their edges, so
    pushing the cursor into one corner first makes every path start from a known
    place (the fork's MailGlitchBattle). A move menu with fewer than four moves
    keeps the cursor off its empty slots. *)

val fight : Wire.button list
(** FIGHT, top left, and A. *)

val bag : Wire.button list
(** BAG, top right, and A. *)

val pokemon : Wire.button list
(** POKEMON, bottom left, and A. *)

val run_away : Wire.button list
(** RUN, bottom right, and A. *)

val move : slot:int -> Wire.button list
(** On the open move menu: to the top-left move, then to [slot] (0-3), without
    the A. *)

val target : Battle.target -> Wire.button list
(** On a double battle's target cursor, without the A. The cursor starts on the
    foe on the left; RIGHT steps past the user to the partner, LEFT to the foe
    on the right (pokefirered battle_controller_player.c,
    HandleInputChooseTarget, both foes standing). *)

val down : int -> Wire.button list
(** [n] DOWNs: a list opened on its top row, to row [n]. *)
