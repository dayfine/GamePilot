(** PLZA's rules for the checkpoint engine ({!Engine_rules.GAME_RULES}). PLZA
    moves in 3D with a camera that follows the player, so there is no tile grid:
    a plan's pose is a zone (a place, and maybe a spot in it), its actions are
    timed walks ({!Walk_args}), and a checkpoint promises what the screen shows
    where it ends. PLZA links the engine only, not [src/pokemon]
    ([docs/roadmap/plza-autostory-port.md]). Pure, and each part prints itself:
    how a plan writes them is [Plza_plan_format], and what a run keeps
    [Plza_event_snapshot]; [Plza_engine] applies the engine to the three. *)

module Walk_args = Walk_args
(** {!Walk_args}: a walk's legs and end. *)

(** Where the player stands: a zone. *)
module Pose : sig
  type zone = { place : string; spot : string option }
  (** A place (["LumioseCity"]), and maybe a spot in it. *)

  (** A pose without a spot holds anywhere in its place. The C++ checks no pose;
      PLZA reads none yet, so its game tells no position ([None]) and the runner
      checks nothing until a zone reader comes. *)
  include Engine_rules.POSE with type t = zone and type observed = zone
end

(** PLZA's actions: its own event kinds. *)
module Action : sig
  type t = Walk of Walk_args.t  (** A timed walk: a plan's [walk]. *)

  include Engine_rules.ACTION with type t := t
end

module Screen_signature = Screen_signature
(** {!Screen_signature}: what the screen shows where a checkpoint starts or
    ends. *)

(** What a PLZA checkpoint promises: its [place], what the screen shows where it
    ends. Unset, the series takes the next checkpoint's start signature, as a
    Pokémon checkpoint's end is the next one's start. *)
module Postconditions : sig
  type t = { place : Screen_signature.t option }

  include
    Engine_rules.POSTCONDITIONS
      with type t := t
       and type reads = Screen_signature.t
end

val ends_at : Action.t -> Pose.t option
(** [None]: a PLZA walk is timed legs, with no target. *)

val position : Postconditions.t -> Pose.t option
(** [None]: PLZA promises no zone. *)

val end_place : Postconditions.t -> Postconditions.t option
(** The promises when they name a [place] (PLZA promises nothing else). *)
