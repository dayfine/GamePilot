(** A console failure as a small fault file (a game's [ConsoleFailures/] folder
    beside its simulation tests), made from a console log's [[Leg]] records and
    raw walk facts by PokemonSimulation's [leg_replay.py]. The file keeps only
    what the simulation cannot work out from its map: where the run started if
    not on its checkpoint's start, the detections it missed, the walks that went
    further than counted, and the people the map lacks. Trainers, NPCs and walls
    come from the map. Where the failure happened and the frame it was checked
    against ride along for the reader.

    {v
    {"checkpoint": "01.02",
     "faults": [{"kind": "hold_through_warp", "step": "past_curtis",
                 "direction": "east", "fade": "unseen", "far_pose_of": "into_oreburgh"}],
     "failed": {"step": "into_oreburgh", "error": "no_banner"},
     "frame": "2026-11-11.png"}
    v}

    Fields the reader does not know (["about"], ["walk"]) are left alone. *)

(** How the walk saw the fade of a warp it went through. *)
type fade = Unseen | Black | Dim | White

type overrun = {
  step : string;
  direction : Grid_geometry.Direction.t;
  tiles : int;  (** 1 when the file leaves it out. *)
  fade : fade;  (** [Unseen] when the file leaves it out. *)
  far_pose_of : string option;
      (** The step of the checkpoint whose pose after it is where the warp
          lands. *)
}
(** A step that went further than the program counted on. *)

(** What went differently on the console than the program counted on. *)
type fault =
  | Fade_missed of int
      (** The nth fade of the run goes unseen, counted within the checkpoint
          from 0. *)
  | Banner_missed of int
      (** The nth map banner of the run goes unseen, counted from 0. *)
  | Moved_further of overrun
      (** The step's counted taps went [tiles] further (onto a warp,
          [far_pose_of]). *)
  | Hold_through_warp of overrun
      (** The step's hold toward [direction] ran on through a warp
          ([far_pose_of]). *)
  | Scene_ends_further of overrun
      (** The player stood [tiles] toward [direction] past where the scene step
          leaves them. *)
  | Moved_less of { step : string; index : int; tiles : int }
      (** The [index]th hold of [step]'s walk (from 1) moved [tiles] fewer than
          it was held for, with nothing on screen: the walker took the move as
          seen. *)
  | Person_stands of { name : string; tile : Grid_geometry.Tile_pos.t }
      (** [name], a person of the map (who wanders or stays put), stood on
          [tile]. *)

val fault_kind_name : fault -> string
(** The file's ["kind"]: ["fade_missed"], ["banner_missed"], ["moved_further"],
    ["hold_through_warp"], ["scene_ends_further"], ["moved_less"],
    ["person_stands"]. *)

type t = {
  name : string;
  checkpoint : string;
  start : (Route_tile.t * Grid_geometry.Direction.t) option;
      (** Where the run starts and which way it faces, if not on the
          checkpoint's start. *)
  faults : fault list;
  failed_step : string;  (** What the console did: the step that failed... *)
  failed_error : string;  (** ...and the start of its error. *)
  frame : string;
      (** The frame the failure was checked against, a file name in the lab's
          failure screenshots. *)
  evidence : string list;  (** The log lines the faults were worked out from. *)
}

val parse : name:string -> string -> (t, string) result
(** Reads the fault file [name] from its text. [Error] names the file and the
    missing, mistyped or unknown field. *)
