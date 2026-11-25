(** The player's money read off the Trainer Card's front (Start menu, the
    player's name), digit by digit ({!Frlg_text.Number_reading},
    {!Frlg_text.Text_lines.trainer_card_money_digit}). New for the end checks:
    the fork reads money only on a Mart's money box
    (Menus/PokemonFRLG_MoneyBoxReader), which needs a clerk. *)

val player_row : int
(** The player's name on the full Start menu: 3. *)

val max_digits : int
(** 6: money stops at 999,999. *)

val close : log:(string -> unit) -> unit
(** From the open card back to the overworld: B, which fades the card out and
    the overworld in with the Start menu open; once that fade-in is over
    ({!Menu_input.await_fade_in}), the menu closed and the talk settle. On mGBA
    (2026-11-24, 04-grind-farfetchd testing run 2) the Start menu read 45 frames
    after the black, in the fade-in's steps, and the B that closes it came then
    and was lost. Fails as [not_closed]. *)

val read : log:(string -> unit) -> int option
(** From the overworld: the card opened, its money read until it shows (the card
    fades in and flips; {!read_timeout_ms}), then {!close}. [None] when no money
    read in time. Fails as [no_start_menu] or [not_closed]. *)

val read_timeout_ms : int
(** 6 s. *)
