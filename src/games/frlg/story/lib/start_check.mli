(** The console's start check after a reload: is the game where the checkpoint
    starts? FireRed has no reader for the map or the tile, so, as the fork's
    [check_console_start()] and [run_start_check()]
    (AutoStory/PokemonFRLG_AutoStoryStartFrames, [frlg/lean]) do, the frame
    after the load is compared with the one kept when the runner saved there
    ({!Frlg_readers.Start_frame}); and the party, read from its summaries, is
    compared with the one the checkpoint starts with (the previous checkpoint's
    promised party, else the roster given with [--party]). A check that cannot
    be made (no kept frame yet, a summary that did not read) is logged and does
    not stop the run, as in the fork; a mismatch stops it. *)

type expected = {
  party : Story.Plan.party option;
  frame : Frlg_readers.Start_frame.t option;
      (** The frame kept when the runner last saved at this start. *)
}

type observed = {
  party_read : string option list option;
  frame_read : Frlg_readers.Start_frame.t option;
}

val check : expected -> observed -> Story.Postcondition_check.result list
(** The party, then the place; nothing for what [expected] leaves out. *)

val mismatches : Story.Postcondition_check.result list -> string list
(** The failed results, one line each; empty: the run may start. *)

val observe : log:(string -> unit) -> expected -> observed
(** In the effect context, from the overworld: the frame first (before a menu
    moves anything), then the party when [expected] names one. *)

val frame_file : states:string -> string -> string
(** [<states>/<id>.start.frame.json]: where the runner keeps checkpoint [id]'s
    start frame. *)

val start_file : states:string -> Story.Pose.declared option -> string option
(** [<states>/<map>.<x>_<y>.start.frame.json] for a start on tiles (its first):
    the frame kept at that start under any checkpoint's id, so a checkpoint
    renamed or split off (mg-04 to mg-04a) finds the frame kept where it starts.
    [None] for no start, a whole map or a zone. *)

val load_frame : string -> (Frlg_readers.Start_frame.t option, string) result
(** [Ok None] when the file does not exist. *)

val write_frame :
  log:(string -> unit) -> string -> Frlg_readers.Start_frame.t -> unit
(** Writes the frame to the file; logged, not fatal, when it cannot. *)

val keep_frame : log:(string -> unit) -> string -> unit
(** Reads the current frame and writes it to the file; logged, not fatal, when
    it cannot. In the effect context. *)

val read_frame : unit -> Frlg_readers.Start_frame.t option
(** The current frame's tiles, with their probes subscribed for the read. *)
