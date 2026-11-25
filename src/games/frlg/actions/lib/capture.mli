(** The ["capture"] game action's decisions: find a wild battle, run from any
    foe that is not a target, throw the plan's ball at a target until caught,
    and send each catch to the party, or to the PC once the party is full. A
    target is the plan's species, or, collecting species, any foe without the
    caught mark. Ported from the fork's run_capture() and capture_message()
    (Programs/AutoStory/PokemonFRLG_AutoStoryCapture, _AutoStoryCaptureRun,
    _AutoStoryCaptureTurns). The game steps come as {!game_steps}, so the
    decisions run on a fake in tests; {!Capture_steps} is the game's.

    Where it differs: no shiny check (the fork hears the shiny sound; GamePilot
    has no audio) and no weakening move ({!Capture_plan}), so the only fainted
    player is one the foe beat after a throw (the fork's ThrowEnd::
    PLAYER_FAINTED, which its console steps never report; {!Capture_steps}
    does). The uncaught target and the ball are new ({!Capture_plan}). *)

(** Where a catch went. *)
type destination = Party | Pc

(** How a throw ended. *)
type throw_end =
  | Caught  (** the catch's first message *)
  | Broke_free  (** the action menu is back *)
  | No_balls  (** the bag has none of the ball; the action menu is back *)
  | Player_fainted
      (** the foe beat the player's Pokemon after the throw: "Use next
          POKéMON?", the battle still on *)
  | Throw_failed  (** neither in time *)

type encounter = {
  species : string option;  (** the foe's slug, if read *)
  caught : bool;  (** its HP box shows the caught mark *)
}
(** What a wild battle's start shows. *)

type game_steps = {
  find_encounter : unit -> bool;
      (** From the overworld in the patch: until a wild battle starts. False if
          none did within its bound. *)
  read_encounter : unit -> encounter;
      (** From a wild battle's start to its action menu. *)
  flee : unit -> bool;
      (** From the action menu: RUN until the overworld is back. False if it
          didn't get away. *)
  throw_ball : unit -> throw_end;
      (** From the action menu: BAG, the plan's ball. *)
  finish_catch : destination -> bool;
      (** From the catch's first message: no nickname, the messages, to the
          overworld. False if it didn't come back. *)
  log : string -> unit;
}

(** How a capture ended. *)
type end_ =
  | All_caught
  | Out_of_encounters
  | Out_of_balls of string option  (** why, when the bag ran out *)
  | No_encounter
  | Player_fainted  (** the battle is still on, at "Use next POKéMON?" *)
  | Failed of string

type catch = { species : string option; destination : destination }
(** One catch: its species, if read. *)

type result = {
  end_ : end_;
  encounters : int;
  balls_thrown : int;
  caught : catch list;  (** in order *)
}

val max_turns : int
(** Throws at one target before giving up on it: 20 (CAPTURE_MAX_TURNS). *)

val party_size : int
(** 6: a full party sends catches to the PC. *)

val run : game_steps -> Capture_plan.t -> party:int -> result
(** From the overworld in the patch, with [party] members. *)

val end_name : end_ -> string
(** The failure code's tail: ["caught"], ["out_of_encounters"], ... *)

val message : Capture_plan.t -> result -> string
(** The run's last line, as capture_message(). *)

val party_after : Party_roster.t -> result -> Party_roster.t
(** The party with each catch that went to it added (["?"] when unread). *)
