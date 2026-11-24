(** FireRed's reader of a plan's postconditions ({!Story.Postcondition_check}):
    what the plan states, each read through its own menu from the overworld and
    back to it in control. The party's species by the summary
    ({!Frlg_actions.Party_species}), the coins by the Coin Case
    ({!Frlg_actions.Coin_case}), the money by the Trainer Card
    ({!Frlg_actions.Trainer_card_money}) and each item's count by its row in the
    bag ({!Frlg_actions.Bag_items.count}), a member's moves by its summary
    ({!Frlg_actions.Summary_moves.read_known}, the member found in the party as
    read), a member's level by its summary ({!Frlg_actions.Member_level}, found
    the same way), each member's held-item mark on the party menu
    ({!Frlg_actions.Mail_glitch_use.read_marks}). Not read (so not checked):
    story flags. A read that fails (a menu that did not show, no Coin Case) is
    logged, leaves its postconditions not read, and B is pressed through what it
    left open back to the overworld for the next. *)

val observe :
  log:(string -> unit) ->
  Story.Plan.postconditions ->
  Story.Postcondition_check.observed

val start_money :
  log:(string -> unit) -> Story.Plan.postconditions -> int option
(** For a promise of the money spent ({!Story.Plan.Money_spent}): the money on
    the Trainer Card at the checkpoint's start, read as at its end, from the
    overworld and back to it. [None], reading nothing, for any other promise;
    [None] too when the read failed. *)

val party_summary : log:(string -> unit) -> Story.Room_policy.member list option
(** Every member's species, level and moves ({!Frlg_actions.Party_summary}),
    from the overworld and back to it; [None] when the read failed. *)
