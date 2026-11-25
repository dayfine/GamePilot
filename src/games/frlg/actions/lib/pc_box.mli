(** From the overworld facing a Pokémon Center's PC to the MOVE POKéMON box
    screen, and back out: BILL'S PC (or SOMEONE'S PC), MOVE POKéMON. GamePilot's
    own (the fork has no MOVE POKéMON walk); it reads the screens as
    {!Pc_deposit} does.

    Not an ordered list of presses: each step looks at the screen and decides
    the next press from what it shows ({!open_next}, {!leave_next}), so a
    message, a fade or a cursor left on another row is handled wherever it
    comes. Both walks stop after {!max_looks} looks. *)

type game_steps = {
  look : unit -> Pc_deposit_steps.look;
      (** The screen, the cursor's row and its label. *)
  press : Pc_deposit_steps.press -> unit;
}
(** What the walk reads and presses in the game. *)

val screen_game_steps : game_steps
(** {!Pc_deposit.look} and {!Pc_deposit.press}; the caller subscribes
    {!Frlg_readers.Pc_screen}'s probes. *)

type opening = {
  booted : bool;  (** A went in at the PC, so the overworld is not the PC. *)
  chosen : bool;  (** A went in on MOVE POKéMON. *)
}
(** Where {!to_box_screen} is, from what it pressed so far. *)

val opening : opening
(** At the PC, nothing pressed. *)

type next =
  | At_box_screen
  | Press of Pc_deposit_steps.press * opening
      (** The press, and where the walk is once it went in. *)

val open_next : opening -> Pc_deposit_steps.look -> next
(** The box screen ([Box_grid], or once MOVE POKéMON was chosen a settled frame
    that reads as the overworld: the box screen with a Pokémon's data shown
    does) is the end. Else A at the PC, B on a message, A on the PC list's top
    row once read, UP on another row, A on MOVE POKéMON once read, DOWN or UP
    toward it on the storage menu, and a wait on anything else. *)

val leave_next : Pc_deposit_steps.look -> Pc_deposit_steps.press option
(** [None] on the overworld; a wait on a fade; B on any other screen. *)

val max_looks : int
(** 40. *)

val to_box_screen : log:(string -> unit) -> game_steps -> unit
(** Walks {!open_next} from {!opening}. Fails as [pc_box] when the box screen
    did not open in {!max_looks} looks. *)

val leave : log:(string -> unit) -> game_steps -> unit
(** From the box screen, B (the box screen can read as the overworld), then
    {!leave_next} until the overworld. Fails as [pc_box] when it did not come
    back in {!max_looks} looks. *)
