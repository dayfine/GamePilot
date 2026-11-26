(** A [bank_in_home] event's args: which gifts go from the game's box to which
    HOME boxes ({!Pokemon_home.Box_moves.t}).

    The args are [{"moves": [...]}], moved in order, each move
    [{"gift": "Vivillon", "box_slot": 2, "home_boxes": [166, 167], "scan":
     "right_to_left"}]: the gift's name (for log lines), its slot in the game's
    Box 1 (the first row, 1 to 6 from the left), the HOME boxes tried in order
    (1 to {!home_box_most}) and the order each is scanned for its first empty
    slot (["left_to_right"] or ["right_to_left"], column by column). No two
    moves name the same gift or slot. The moves are the plan's for now:
    plza.claim-gifts' gift catalog, whose entries carry each gift's box slot and
    HOME box, is to supply them. *)

val home_box_most : int
(** 300: the last HOME box, as the box counter's "/300" says. *)

val of_args : Json_field.obj -> (Pokemon_home.Box_moves.t list, string) result
(** The moves the args name; [Error] on a field missing, unknown or out of
    range, no move, or two moves of one gift or slot. *)
