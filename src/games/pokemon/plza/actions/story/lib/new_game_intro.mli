(** 01.00a: from the Switch HOME with no PLZA save, a new game up to "Confirm
    Choices", confirming nothing. Ported from PokemonLZA_AutoStoryNewGame.cpp
    and its launch, PokemonLZA_AutoStoryLaunch.cpp (branch
    [lab/dev-plza-slice1]), their steps, order, presses and waits:

    + the choices are checked before any press ({!New_game_choices.problem});
    + HOME must read within 2 s, else B (80 ms, 1 s after) to wake a dimmed
      screen and HOME within 2 s more;
    + PLZA is launched from HOME ([launch]);
    + the language list must show within 60 s (read every 250 ms);
    + on it, at most 20 reads: on the language's entry A (80 ms, 500 after),
      else one D-pad step toward it, column first (80 ms, 600 after: faster taps
      are dropped);
    + the look picker must show within 20 s; it opens with no highlight, and the
      first tilt highlights a look that varies from launch to launch, so: at
      most 24 settled reads (two reads 150 ms apart agreeing, 14 reads at most),
      tilting the left stick left on a read with no highlight (at most 6 times),
      A (80 ms, 500 after) on the look, else one tilt toward it, column first (a
      full tilt 150 ms, 500 after: the D-pad does not move it);
    + the name keyboard must show within 20 s, then 1 s for it to slide in;
    + the name is typed ({!Switch_home.Keyboard_typing});
    + + (80 ms, 500 after), at most 3 times (Chinese keyboards take one to
      accept the text), until Confirm Choices reads within 5 s of one, stopping
      when the keyboard is gone; then Confirm Choices within 15 s.

    A refusal or failure ends with {!New_game_choices.by_hand_hint}.

    Where it differs: the keyboard's "0/N" counter is not read (OCR); the
    language's limit holds, as the fork's does when its counter does not read.
    Simplified Chinese is refused ({!New_game_choices}). The fork's debug
    captures of each screen are not taken. The launch is the caller's ([launch]);
    on the console it walks HOME's row to PLZA's tile by its title, as the fork
    does, matching a template instead of OCR
    (the autostory program's Live_intro_screen). *)

type game_steps = {
  read_screen : unit -> New_game_screen.t;
      (** Read the screen once the inputs are done. *)
  submit : Wire.command list -> unit;
      (** Send inputs and return once they are done. *)
  launch : unit -> (unit, string) result;
      (** From HOME: close the running game, if any, and start PLZA, up to its
          launch's black. *)
  now : unit -> float;  (** The daemon's clock, in ms. *)
  log : string -> unit;
}
(** What 01.00a reads and does on the console. *)

val run : game_steps -> New_game_choices.t -> Steps.outcome
(** [Error] [new_game_refused] (repeats) when the choices cannot be played
    (before any press) or HOME is not on screen (one B pressed);
    [new_game_failed] when the launch fails, a screen does not show, a highlight
    does not reach the choice, or the name does not type. *)
