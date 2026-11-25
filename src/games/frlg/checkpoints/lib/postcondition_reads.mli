(** FireRed's reader of a plan's postconditions
    ({!Checkpoints_run.Postcondition_check}): what the plan states, each read
    through its own menu from the overworld and back to it in control. The
    party's species by the summary ({!Frlg_actions.Party_species}), the coins by
    the Coin Case ({!Frlg_actions.Coin_case}), the money by the Trainer Card
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
  Checkpoints_plan.Plan.postconditions ->
  Checkpoints_run.Postcondition_check.observed

val at_start :
  log:(string -> unit) ->
  Checkpoints_plan.Plan.postconditions ->
  Checkpoints_run.Postcondition_check.start
(** Reads now, at the checkpoint's start, what a promise of a change needs: the
    money for a promise of the money spent ({!Engine_promise.Money.Spent}), the
    coins and each item promised as gained ({!Engine_promise.Count.Gained}),
    each as at the end, from the overworld and back to it; nothing for a plan
    with no such promise. With no Coin Case in the bag the coins at the start
    are 0. A read that failed stays unread, so its promise is not checked. *)

val party_summary :
  log:(string -> unit) -> Checkpoints_run.Room_policy.member list option
(** Every member's species, level and moves ({!Frlg_actions.Party_summary}),
    from the overworld and back to it; [None] when the read failed. *)

val trainer_card :
  log:(string -> unit) -> Frlg_readers.Trainer_card_front.t option
(** The badges and stars on the Trainer Card's front
    ({!Frlg_actions.Trainer_card_badges}), from the overworld and back to it;
    [None] when they did not read. *)
