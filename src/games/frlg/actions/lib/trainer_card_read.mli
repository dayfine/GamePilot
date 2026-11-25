(** One read of the Trainer Card's front, for any look at it (the badges and
    stars, the Pokédex count): the card opened as {!Trainer_card_money} opens it
    (Start menu, the player's name), looked at until two looks agree, then
    closed. New: the fork reads neither. Two looks must agree because the card
    fades in: a half-faded frame must not stand as the read, and a B pressed
    while it fades in is lost (mGBA, 02-route10-new-species verification run 1).
*)

type 'a game_steps = {
  open_card : unit -> unit;
      (** From the overworld: the card opened, its front fading in. *)
  look : unit -> 'a option;
      (** What the front reads now; [None] while it does not show. *)
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

val read_with :
  'a game_steps -> describe:('a -> string) -> unread:string -> 'a option
(** Opens the card, looks until two looks {!reread_ms} apart read the same,
    closes it. [None] when none did in {!read_timeout_ms}. Logs
    ["Trainer Card: <describe read>."], or ["Trainer Card: <unread>."]. The card
    is closed either way. *)

val console_game_steps :
  log:(string -> unit) -> look:(unit -> 'a option) -> 'a game_steps
(** In the effect context, in the menu actions' probes ({!Menu_input.run}):
    START and the player's row, [look] on the latest frame, B to the Start menu,
    the menu closed and the talk settle ({!Trainer_card_money.close}). Fails as
    [no_start_menu] or [not_closed]. *)

val read :
  log:(string -> unit) ->
  look:(unit -> 'a option) ->
  describe:('a -> string) ->
  unread:string ->
  'a option
(** {!read_with} on {!console_game_steps}, with
    {!Frlg_readers.Trainer_card_front.probes} subscribed. *)
