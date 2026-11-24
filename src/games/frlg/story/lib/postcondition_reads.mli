(** FireRed's reader of a plan's postconditions ({!Story.Postcondition_check}):
    what the plan states, each read through its own menu from the overworld and
    back to it in control. The party's species by the summary
    ({!Frlg_actions.Party_species}), the coins by the Coin Case
    ({!Frlg_actions.Coin_case}), the money by the Trainer Card
    ({!Frlg_actions.Trainer_card_money}) and each item's count by its row in the
    bag ({!Frlg_actions.Bag_items.count}). Not read (so not checked): story
    flags. A read that fails (a menu that did not show, no Coin Case) is logged,
    leaves its postconditions not read, and B is pressed through what it left
    open back to the overworld for the next. *)

val observe :
  log:(string -> unit) ->
  Story.Plan.postconditions ->
  Story.Postcondition_check.observed
