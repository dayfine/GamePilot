(** frlg.ace's 01-enter-code (docs/design/FRLG-ACE-Execution.md, "The program"):
    the boxes checked before anything is typed, then all 14 box names set to the
    code of the item the run's [item] option names ({!Ace_presets}), from the
    overworld facing a Pokémon Center's PC and back there. New, not in the fork,
    which has no ACE.

    Boxes are found by their titles ({!Frlg_text.Box_title}): each title is read
    against every name a box may hold ({!Ace_presets.known_names}: the game's
    [BOX<n>] and every item's code). From the box the PC shows, RIGHT until a
    title reads as Box 1's, then one RIGHT per box, each title read again. A
    RIGHT the screen dropped (seen on mGBA right after a rename: the title still
    reads as the box before) is pressed again, up to three times; any other
    title that reads as another box's name (and not this one's) fails rather
    than renaming the wrong box. Both actions end with RIGHT from Box 14, which
    must reach Box 1.

    Each box is also told by its wallpaper, which no name changes: a new game
    gives Box [n] Forest, City, Desert, Savanna in turn
    ({!Frlg_readers.Pc_box_screen.default_wallpaper}), so after each RIGHT the
    title's bar must show the box's own, and a bar that still shows the box
    before's is a dropped RIGHT, pressed again as above: that tells Boxes 12 to
    14, all named [A], apart. A wallpaper the player changed (a box screen whose
    bar shows none of the four, or another box's) fails as [ace_box_wallpaper],
    naming the box and the wallpaper to set back, before anything more is
    pressed. A read with no box screen (no frame came, or the frame is not the
    box screen) is not a wallpaper's fault: it is read once more, and fails as
    [ace_box_unread] if it still shows none. Box 3 is still found by 0x0351 in
    its first slot too. *)

(** What the title's bar shows. *)
type wallpaper_read =
  | No_box_screen
      (** No frame came, or the frame does not show the box screen
          ({!Frlg_readers.Pc_screen.box_screen_shown}). *)
  | Shows of Frlg_readers.Pc_box_screen.wallpaper option
      (** The box screen, its bar showing this one of the new game's four
          wallpapers ({!Frlg_readers.Pc_box_screen.title_wallpaper}); [None] for
          any other. *)

type game_steps = {
  open_move_pokemon : unit -> unit;
      (** From the overworld facing the PC to MOVE POKéMON's box screen, the
          hand on the shown box's first slot. *)
  press : Wire.button -> unit;  (** A press and its wait. *)
  read_title : string list -> string option;
      (** Which of these the box title reads, if any. *)
  read_wallpaper : unit -> wallpaper_read;
      (** What the title's bar shows, from one frame. *)
  slot_empty : unit -> bool option;
      (** PKMN DATA shows no text: the slot under the hand holds no Pokémon. *)
  ace_at_hand : unit -> bool;
      (** The slot under the hand shows species 0x0351 as frlg.ace_setup leaves
          it ({!Ace_mail.slot_verdict} for Box 3 slot 1). *)
  name_title : others:string list -> string -> unit;
      (** With the hand on the title, the box renamed and read back
          ({!Box_rename.name_on_title}). *)
  close : unit -> unit;  (** Out of the box screen and the PC. *)
}
(** What the checks and the typing read and press in the game. *)

val empty_slots : (int * int list) list
(** The slots that must be empty before the code is typed: Box 13 slot 7 on and
    all of Box 14 (pomeg's FRLG FAQ: 0x0351's long name runs over Box 13 slots
    7-9 now and then; the code slides through their zero words into the box
    names). *)

val check_boxes : game_steps -> log:(string -> unit) -> Ace_presets.t -> unit
(** Box 3 slot 1 shows 0x0351 and every slot of {!empty_slots} is empty, each
    read with the hand on it. Fails as [ace_box_lost] (no title reads as Box 1
    in 14 scrolls, or a box's title reads as another box's), [ace_box_wallpaper]
    (a box shows another wallpaper than its default), [ace_box_unread] (twice no
    box screen where a box's wallpaper is read), [ace_not_in_slot] or
    [ace_box_not_empty] (a slot holds a Pokémon, or does not read). *)

val enter_code :
  game_steps ->
  log:(string -> unit) ->
  Ace_presets.t ->
  Ace_presets.item ->
  unit
(** Every box's title read and, unless it reads the item's name already, renamed
    to it: a title that reads none of the names is retyped. Fails as
    [ace_box_lost], [ace_box_wallpaper], [ace_box_unread], or as
    {!Box_rename.name_on_title} does. *)

val screen_game_steps : log:(string -> unit) -> game_steps
(** {!Ace_trigger.screen_game_steps}'s reads and presses, and
    {!Box_rename.screen_game_steps}'s naming; the wallpaper read from one frame
    of {!Frlg_readers.Pc_box_screen}'s and {!Frlg_readers.Pc_screen}'s probes
    ({!Ace_trigger.box_reading}), always with the hand on the title: a Pokémon's
    picture in PKMN DATA hides the lilac edge
    {!Frlg_readers.Pc_screen.box_screen_shown} reads. *)

val handlers :
  log:(string -> unit) ->
  options:Run_options.t ->
  (string * Pokemon_engine.Game.game_action) list
(** [ace_check_boxes] and [ace_enter_code], no args: the code is the one of the
    run's [item] option; an item not in the table, or no [item] option, fails as
    [bad_args] before anything is pressed. *)
