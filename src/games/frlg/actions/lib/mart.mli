(** A ["mart"] action, facing a Mart's clerk: BUY, each line bought, then back
    to the overworld. Ported from the fork's ConsoleMartActions
    (Programs/AutoStory/PokemonFRLG_AutoStoryMart), waiting on readers where it
    waits by time:

    - A to the clerk, then A on BUY once the text box shows (BUY is on top).
    - The BUY list: its money box ({!Frlg_readers.Money_box}).
    - Per line: the cursor moved to the item's row (counted: no reader names a
      BUY list row yet), A, the quantity typed after {!how_many_wait_ms} ("How
      many?" drops presses while it prints; no reader for the quantity box), A,
      then A on the Yes/No once it shows and A on "Here you are!" until the list
      is back.
    - B until the money box is gone, then the talk settle. *)

val how_many_wait_ms : int
(** 2500, the fork's measured wait. *)

val run :
  log:(string -> unit) -> Mart_plan.stock_item list -> Mart_plan.t -> unit
(** Raises {!Menu_input.Action_failed}: [mart_no_clerk], [mart_no_buy_list],
    [mart_no_confirm], [mart_not_back]. *)
