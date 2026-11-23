(** Celadon's Game Corner, ported from the fork's Mail Glitch actions
    (Programs/MailGlitch/PokemonFRLG_MailGlitchActions: [run_buy_coins()],
    [run_redeem_prize_mon()]). The clerks' choice boxes have no reader yet, so
    each is waited out by the fork's measured {!choice_wait_ms} after the page
    before it; the pages themselves are waited on. *)

val coin_batches : int -> int list
(** The coins clerk sells 50 or 500 at a time ([0]: 50 COINS, [1]: 500 COINS):
    the batches that make up a total, 500s first. The total is a multiple of 50;
    see {!coins_of_args}. *)

val coins_of_args : where:string -> Grid_maps.Json_field.obj -> int
(** ["coins"]: a positive multiple of 50. *)

val prize_slots : int
(** The prize clerk's Pokémon: 5 (Abra first). *)

val fire_red_prizes : string list
(** The prizes by row on FireRed: Abra, Clefairy, Dratini, Scyther, Porygon
    (LeafGreen's differ). *)

val prize_slot_of_args : where:string -> Grid_maps.Json_field.obj -> int
(** ["slot"]: the prize's row from 0. *)

val choice_wait_ms : int
(** 1800: the choice box showing after its page. *)

val buy_coins : log:(string -> unit) -> int -> unit
(** Facing the coins clerk: per batch, A, the welcome page turned, the batch
    chosen, then the talk settle. Fails as [coins_no_clerk]. *)

val redeem_prize_mon : log:(string -> unit) -> int -> unit
(** Facing the Pokémon prize clerk: A, the page turned after {!choice_wait_ms}
    (his blue arrow has no reader; the fork turns it by time too), the prize's
    row, A, YES, then the talk settle (whose B declines a nickname). Fails as
    [prize_no_clerk] or [prize_no_question]. *)
