(** When a warp's fade-in is over: the room has come up from the fade and stands
    still in full light, so the player takes input. The fade probe
    ({!Frlg_readers.Screen_facts.fade_id}) reads "no fade" from the first lit
    frame of the fade-in, before the game gives the player control back.

    After some warps the room first shows dim and still for about 35 frames,
    then fades in. On mGBA (2026-11-24, 01-to-one-island testing run 2, into
    Cinnabar Island's Pokemon Center) the screen came up from black at a channel
    sum of 35 (stddev sum 34, so no fade), held there for 33 frames, then rose
    in steps over 14 frames to 351; a hold sent during the dim spell lost its
    first tile.

    The fork's walker waits a fixed 300 ms after the black ends
    (Overworld/PokemonFRLG_OverworldWalk.cpp), which the dim spell outlasts. We
    deliberately differ: the fade-in is over once the screen's brightness has
    changed from its first lit frame and then stood still for {!still_ms}; a
    screen that never changes is taken as up after {!unchanged_ms}.

    This is FireRed's one rule for when a warp's or a door's fade-in is over:
    the walker ({!Route_walk}) waits on it after every warp, a closed menu's
    settle (the actions' [Scene_readings]) on every fade it sees, and the
    actions' [Menu_input.await_fade_in] (#73) after the bag or the Trainer Card
    closes. The core settle ({!Screen_state.Settle}) has no door rule of its
    own. *)

type t
(** A watcher, from the first lit frame on. *)

val step_min : float
(** 10: a change in the fade probe's channel sum at least this large is a step
    of the fade-in. *)

val still_tolerance : float
(** 4: the screen stands still while its channel sum stays within this of where
    the still spell began (an NPC walking, water shimmering). *)

val still_ms : float
(** 200 ms: still this long after a change ends the fade-in. The game steps a
    warp's fade-in every 2 frames, or every 4 with the door's delayed fade
    (pret's [WarpFadeInScreenWithDelay]): a still spell between steps is
    shorter. *)

val unchanged_ms : float
(** 1000 ms: a screen that never changed from the first lit frame is up after
    this, longer than the dim spell (35 frames, 586 ms). *)

val create : Effects.measurements -> t
(** A watcher whose first lit frame is this one. *)

val seen : t -> Effects.measurements -> bool
(** Feeds the watcher one later frame: whether the fade-in is over by it. Frames
    go in order; one without the fade probe is skipped. *)

type watch
(** Every frame of a span, through any number of fades: whether one is still to
    finish its fade-in. A menu that closes to the overworld (the party, a
    summary) fades to black and back in through the same dim spell as a warp: on
    mGBA (2026-11-24, 04-grind-farfetchd testing run 2, out of the summary) the
    screen came up from black at a channel sum of 53, held there for 33 frames,
    then rose in steps over 14 frames to 541; the settle's B came 11 frames into
    the dim spell and again in the middle of the steps. *)

val watch : unit -> watch
(** A watch that has seen no fade. *)

val watch_frame : watch -> Effects.measurements -> unit
(** Feeds the watch one frame, in order: a fade ({!Screen_state.Fade}) starts it
    over; its first lit frame starts a watcher ({!create}), which every later
    frame feeds ({!seen}) until it is over. *)

val fading : watch -> bool
(** A fade showed and its fade-in is not over yet. *)

val came_up : watch -> bool
(** A fade showed and its fade-in is over, with no fade since. *)
