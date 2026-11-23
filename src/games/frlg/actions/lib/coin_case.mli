(** The Game Corner coins read off the Coin Case's message in the bag
    (["Your COINS:\n<coins>"], pokefirered item_use.c [FieldUseFunc_CoinCase]),
    digit by digit ({!Frlg_text.Number_reading},
    {!Frlg_text.Text_lines.bag_message_digit}). New for the end checks: the fork
    buys coins ([run_buy_coins()] in
    Programs/MailGlitch/PokemonFRLG_MailGlitchActions.cpp) without reading them.
*)

val max_digits : int
(** 4: coins stop at 9,999. *)

val read : log:(string -> unit) -> int option
(** From the overworld: the Key Items pocket ({!Bag_items.open_pocket_top}),
    COIN CASE selected by its name, A, USE (row 0 of its menu), the count read
    until it shows ({!Trainer_card_money.read_timeout_ms}), B to the bag, the
    bag closed, the talk settle. [None] when no count read in time. Fails as
    [no_bag], [no_pocket], [not_in_bag], [no_item_menu] or [not_closed]. *)
