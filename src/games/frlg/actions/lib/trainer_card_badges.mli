(** The badges and stars read off the Trainer Card's front
    ({!Frlg_readers.Trainer_card_front}): what a plan's [badges] and
    [hall_of_fame] preconditions are checked on. New: the fork reads no badges.
    Opened as {!Trainer_card_money} opens it (Start menu, the player's name);
    not flipped, as FireRed draws the badges and the stars on the front (pret
    pokefirered [DrawStarsAndBadgesOnCard]). *)

type game_steps = {
  open_card : unit -> unit;
      (** From the overworld: the card opened, its front fading in. *)
  look : unit -> Frlg_readers.Trainer_card_front.t option;
      (** The front as it reads now; [None] while it does not show. *)
  wait : int -> unit;  (** Wait this many ms. *)
  now_ms : unit -> float;  (** The clock, in ms. *)
  close_card : unit -> unit;  (** Back to the overworld. *)
  log : string -> unit;  (** Where {!read_with} logs the read. *)
}
(** The steps in the game this module takes; {!read_with} decides. *)

val read_timeout_ms : int
(** How long the card may take to fade in and read the same twice: 6 s, as
    {!Trainer_card_money.read_timeout_ms}. *)

val reread_ms : int
(** Between two looks: 300 ms. *)

val read_with : game_steps -> Frlg_readers.Trainer_card_front.t option
(** Opens the card, looks until two looks {!reread_ms} apart read the same
    badges and stars, closes it. [None] when none did in {!read_timeout_ms}.
    Logs ["Trainer Card: 8 badges (boulder, ...), 1 star."]. The card is closed
    either way. *)

val console_game_steps : log:(string -> unit) -> game_steps
(** In the effect context, in the menu actions' probes ({!Menu_input.run}):
    START and the player's row, a look on the latest frame, B to the Start menu,
    the menu closed and the talk settle ({!Trainer_card_money.close}). Fails as
    [no_start_menu] or [not_closed]. *)

val read : log:(string -> unit) -> Frlg_readers.Trainer_card_front.t option
(** {!read_with} on {!console_game_steps}, with the reader's probes subscribed.
*)
