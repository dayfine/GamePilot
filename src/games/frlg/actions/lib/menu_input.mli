(** The presses and waits every FireRed menu action is made of: a button press,
    a run of D-pad taps, and an await on a reader that fails the action with a
    named cause when the screen never comes. An action body raises
    {!Action_failed} through these and {!run} turns it into the story's outcome,
    so a flow reads as the list of its steps. *)

exception Action_failed of Story.Failure.cause

val fail : ?repeats:bool -> string -> string -> 'a
(** Raises {!Action_failed} with [Story.Failure.cause code detail]. *)

val probes : Wire.probe_spec list
(** What the menu actions read: {!Scene_looks.probes}, the party, the bag and
    the money box. *)

val run : (unit -> unit) -> (unit, Story.Failure.cause) result
(** Runs the body with {!probes} subscribed; [Error] with the cause it failed
    with. *)

val button_hold_ms : int
(** A button press: 160 ms held, as the fork's menus press. *)

val tap_hold_ms : int
(** A menu cursor tap: 80 ms held... *)

val tap_release_ms : int
(** ...then 240 ms released before the next, so the menu takes each one. *)

val screen_timeout_ms : int
(** How long a menu or a text box may take to show after the press that opens
    it: 3 s. *)

val press : ?cooldown_ms:int -> Wire.button -> unit
(** One press of the button, then [cooldown_ms] (default 0). *)

val taps : Wire.button -> int -> unit
(** [n] cursor taps of the button; none for [n <= 0]. *)

val moves : from:int -> to_:int -> unit
(** Taps down (or up) that move a menu cursor from row [from] to row [to_]. *)

val await_screen :
  ?timeout_ms:int ->
  code:string ->
  string ->
  (Effects.measurements -> bool) ->
  Effects.measurements
(** The first frame the reader holds on; fails as [code] with
    ["<what> did not show"] after [timeout_ms] (default {!screen_timeout_ms}).
*)

val open_start_menu_row : int -> unit
(** START, the Start menu read, the cursor moved from the row it reads on to
    this row (from 0 at the top), then A. Fails as [no_start_menu]. *)

val settle_back : label:string -> log:(string -> unit) -> unit
(** The talk settle ({!Scene_looks.settle}) back to a quiet overworld: B through
    the rest of a menu's or a talk's text. Fails as its cause. *)

val max_pages : int
(** Text pages {!answer_yes} turns before the question must show: 8. *)

val answer_yes : code:string -> string -> unit
(** After a talk: A on each page with the advance arrow until the Yes/No box
    shows, then A on YES (the cursor starts there). Fails as [code] with
    ["<what> did not show"] when no page or question comes. *)

val press_until :
  ?max_presses:int ->
  code:string ->
  string ->
  Wire.button ->
  cooldown_ms:int ->
  (Effects.measurements -> bool) ->
  unit
(** Presses the button, [cooldown_ms] apart, until the reader holds (checked
    before each press and while it runs); at most [max_presses] (default 45),
    then fails as [code]. *)

val dpad : Grid_maps.Direction.t -> Wire.button
(** The D-pad button of a direction. *)

val hold : hold_ms:int -> cooldown_ms:int -> Wire.button -> Wire.command
(** A press of the button held [hold_ms], then [cooldown_ms] released. *)

val close_press_ms : int
(** Between the B presses of {!close}: 500 ms. *)

val close : string -> (Effects.measurements -> bool) -> unit
(** B until the reader no longer holds: a bag, a party or a list closed, which
    the settle's look can't tell from the overworld. Fails as [not_closed]. *)
