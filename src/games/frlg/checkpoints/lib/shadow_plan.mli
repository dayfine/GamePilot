(** The plans of the runs that are not story checkpoints, so they run through
    the checkpoint runner ({!Checkpoint_run.run}) like one and show their steps
    and story lines on the watch page: the pre-flight of a save and the
    make-room party read. Each event is a game action the caller supplies
    ([Checkpoint_run.run ~actions]), named by the event's id. Generated, never
    written to a plan folder, as {!Make_room}'s 00-make-room. *)

val preflight_steps : string list
(** ["soft_reset"] (back to the save: the soft reset, on mGBA the start state),
    ["check_start"] (the place, against the start frame), ["read_party"] (the
    members' summaries), ["read_trainer_card"] (money, badges and stars by the
    Trainer Card, coins, bag items), ["verdict"] (the table). The place is
    checked first, on the frame the reload left, as the pre-flight did before.
*)

val make_room_steps : string list
(** ["soft_reset"], ["read_party"], ["plan_deposit"] (the room policy's pick and
    00-make-room's plans). *)

val plan : id:string -> title:string -> string list -> Pokemon_engine.Plan.t
(** A checkpoint [id] whose events are game actions named by these ids. *)
