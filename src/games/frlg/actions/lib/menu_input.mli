(** The presses and waits every FireRed menu action is made of: a button press,
    a run of D-pad taps, and an await on a reader that fails the action with a
    named cause when the screen never comes. An action body raises
    {!Action_failed} through these and {!run} turns it into the story's outcome,
    so a flow reads as the list of its steps. *)

exception Action_failed of Checkpoints_run.Failure.cause

val fail : ?repeats:bool -> string -> string -> 'a
(** Raises {!Action_failed} with [Checkpoints_run.Failure.cause code detail]. *)

val raise_error : (unit, Checkpoints_run.Failure.cause) result -> unit
(** Raises {!Action_failed} with an [Error]'s cause; [Ok] does nothing. *)

val probes : Wire.probe_spec list
(** What the menu actions read: {!Scene_looks.probes}, the party and a member's
    menu, the bag and the money box. *)

val run : (unit -> unit) -> (unit, Checkpoints_run.Failure.cause) result
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

val mash : Wire.button -> int -> unit
(** The fork's [pbf_mash_button] for [ms]: a tap ({!tap_hold_ms} then
    {!tap_release_ms}) every 320 ms for that long. *)

val moves : from:int -> to_:int -> unit
(** Taps down (or up) that move a menu cursor from row [from] to row [to_], for
    a menu with no cursor reader (a Mart's list); the others move by reading
    ({!Menu_cursor}). *)

val await_screen :
  ?timeout_ms:int ->
  code:string ->
  string ->
  (Effects.measurements -> bool) ->
  Effects.measurements
(** The first frame the reader holds on; fails as [code] with
    ["<what> did not show"] after [timeout_ms] (default {!screen_timeout_ms}).
*)

val settle_back : label:string -> log:(string -> unit) -> unit
(** The talk settle ({!Scene_looks.settle}) back to a quiet overworld: B through
    the rest of a menu's or a talk's text. Fails as its cause. *)

val fade_in_timeout_ms : int
(** How long {!await_fade_in} waits: 5 s. *)

val await_fade_in : code:string -> string -> unit
(** After a press that closes a menu through a black fade (the bag, the Trainer
    Card): every frame watched ({!Frlg_overworld.Warp_fade_in.watch}) until the
    fade has shown and its fade-in is over, so that the next B lands on a screen
    that takes it. A look alone reads the dim spell as the overworld (no fade)
    and the steps up as a screen that moves. Fails as [code] with
    ["<what> did not show"] after {!fade_in_timeout_ms}. *)

val close_to_overworld : label:string -> log:(string -> unit) -> unit
(** From the party, a member's menu or a summary, as the settle's [Menu_closed]
    rule closes it ({!Screen_state.Settle.rule}): B until the overworld shows
    with none of these menus, still for 0.5 s; not the talk's 5 s quiet, as no
    text comes after a menu. No B and no quiet while a menu's fade-in is still
    coming up ([await_fade_in] of {!Scene_looks.settle}). Fails as its cause. *)

val max_pages : int
(** A presses {!answer_yes} gives the pages before the question must show: 8. *)

val page_press_ms : int
(** The wait after an A on a page, before the next look: 600 ms, the fork's
    [answer_yes_no] (its 300 ms after the press, then its 300 ms poll). As
    there, a page whose arrow still shows gets another A: an A the game takes
    while it prints only hurries the text (mg-02 testing run 10: Elyssa's "Do
    you have a SPEAROW?" kept its arrow after an A 90 ms after it showed). *)

val question_input_ms : int
(** How long the Yes/No box shows before {!answer_yes} presses: 300 ms. The
    fork's [answer_yes_no] (AutoStory/PokemonFRLG_AutoStoryActions) polls the
    screen every 300 ms, so its press comes up to that long after the box shows;
    GamePilot sees the box within a frame, and the game drops an A that comes
    that early (mGBA, Route 16's Cut, mg-02 testing run 4: an A 3 ms after the
    box was lost and the settle's B then answered NO; run 5's A, 118 ms after,
    was taken). *)

val answer_cooldown_ms : int
(** The fork's wait after its answer: 800 ms. *)

val answer_yes :
  code:string -> taken:(Effects.measurements -> bool) -> string -> unit
(** After a talk, one look at a time, by what the screen shows: the Yes/No box
    with its arrow ({!Dialog.yes_no_cursor}) gets YES as the fork's
    [answer_yes_no] answers it (UP if the arrow is on NO, A {!question_input_ms}
    after the box showed, then {!answer_cooldown_ms}); a page with the advance
    arrow gets an A; once one of those A presses has gone in, the screen [taken]
    reads (what YES leads to) ends it too, as that A took YES. Fails as [code]
    with ["<what> did not show"] when no page, question or [taken] screen comes.

    The A on a page races the question: red text (a woman's) reads as the arrow
    while it prints, and on console B a frame shows the game 160-335 ms late, so
    the last page's A can land on the Yes/No box as it draws (mg-02 testing,
    2026-11-24: Elyssa's offer, YES taken, the party up, the question never
    seen). YES is the box's default, so the [taken] screen means YES. The moves
    are {!Screen_state.Choice_talk}'s. *)

val answer_yes_if_asked : timeout_ms:int -> bool
(** YES to a Yes/No box that shows within [timeout_ms], answered as
    {!answer_yes} answers it; whether one showed. *)

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

val max_faded_closes : int
(** How many times {!close_through_fades} closes: 3, the mail editor, the party
    and the bag after a mail is given. *)

val fade_start_ms : int
(** How long {!close_through_fades} looks for a fade when the reader did not
    hold as it began: 1 s. *)

val close_through_fades : string -> (Effects.measurements -> bool) -> unit
(** A bag or a party that closes through a black fade ({!await_fade_in}): B
    until the reader no longer holds ({!close}), then every frame watched until
    the fade-in after it is over; again while the reader holds then, as a party
    opened from the bag closes to the bag through a fade of its own. When the
    reader did not hold and no fade shows within {!fade_start_ms}, nothing is
    waited for and the caller's settle goes on: the party's message after a held
    item is switched ("The LEPPA BERRY was taken and replaced with the
    ANTIDOTE.") hides the party's prompt, which {!Frlg_readers.Party_menu}
    reads, so that close is still the talk settle's B (mGBA, 2026-11-25,
    08-activate-and-verify give_dup_item). No B goes in while a fade or its
    fade-in is still coming up: on mGBA (2026-11-24, 08-activate-and-verify
    testing run 1) the talk settle after a given mail pressed B in the editor's
    black, and after verify_mail_glitch's party closed, in its fade-out. We
    deliberately differ from the fork, which mashes B through them. Fails as
    [not_closed]: after {!max_faded_closes} closes, or with
    ["the screen after <what> did not show"] when no fade-in is over within
    {!fade_in_timeout_ms}. *)
