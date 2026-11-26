(** A [bank_in_home] event's args, and a run's options over them: which gifts go
    from the game's box to which HOME boxes ({!Pokemon_home.Box_moves.t}).

    The args are [{"moves": [...]}], moved in order, each move
    [{"gift": "Vivillon", "box_slot": 2, "home_boxes": [166, 167], "scan":
     "right_to_left"}]: the gift's name (for log lines and its option), its slot
    in the game's Box 1 (the first row, 1 to 6 from the left), the HOME boxes
    tried in order (1 to {!home_box_most}) and the order each is scanned for its
    first empty slot (["left_to_right"] or ["right_to_left"], column by column).
    No two moves name the same gift or slot.

    A run's option [<gift>-boxes] (the gift's name in lower case:
    [vivillon-boxes=150,151]) replaces that gift's [home_boxes]; the plan's are
    the default. *)

val home_box_most : int
(** 300: the last HOME box, as the box counter's "/300" says. *)

val of_args : Json_field.obj -> (Pokemon_home.Box_moves.t list, string) result
(** The moves the args name; [Error] on a field missing, unknown or out of
    range, no move, or two moves of one gift or slot. *)

val option_key : Pokemon_home.Box_moves.t -> string
(** The option that sets the move's HOME boxes: ["vivillon-boxes"]. *)

val boxes_of_text : key:string -> string -> (int list, string) result
(** An option's value, ["166,167"]: HOME boxes separated by commas, each 1 to
    {!home_box_most}; [Error] naming [key] otherwise. *)

val with_options :
  Run_options.t ->
  Pokemon_home.Box_moves.t list ->
  (Pokemon_home.Box_moves.t list, string) result
(** Each move with its HOME boxes from its option when the run gives one;
    [Error] on a value {!boxes_of_text} refuses, or a [*-boxes] option for a
    gift none of the moves names. *)

val moves :
  Run_options.t ->
  Json_field.obj ->
  (Pokemon_home.Box_moves.t list, string) result
(** {!of_args}, then {!with_options}. *)
