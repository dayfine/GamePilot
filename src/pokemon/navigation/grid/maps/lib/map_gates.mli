(** Barriers the story opens or closes, and the switches some of them follow.
    Types only; {!Map_data} reads them from a map file's [gates] and [switches]
    tables, and {!Gate_state} records which are open. *)

(** What opens a gate that has its own event flag. *)
type opener =
  | Card_key
      (** ["card_key_face_a"]: faced and opened with A, once the player holds
          the Card Key *)
  | Quiz_answer
      (** ["quiz_answer"]: the right answer at a quiz machine (Cinnabar Gym) *)
  | Cut
      (** ["cut"]: a cut tree; its flag is temporary, so every warp closes it
          again *)
  | Rock_smash  (** ["rock_smash"]: a rock cleared by Rock Smash *)

(** What a gate's state follows. *)
type control =
  | Flag of { opener : opener; flag : string }
      (** Open once the game sets [flag]; closed at a new game. *)
  | Switch of { switch_id : string; open_when_on : bool }
      (** Open while the switch [switch_id] (a key of the map's switches) is on,
          if [open_when_on], or while it is off otherwise. *)

type gate = {
  gate_id : string;
  gate_tiles : Tile_pos.t list;  (** Non-empty; each in this gate only. *)
  open_tile : Tile_kind.t;  (** What the tiles read as while open. *)
  open_at_new_game : bool;
  control : control;
}

type statue = {
  statue_tile : Tile_pos.t;
  face_from : Tile_pos.t;
  facing : Direction.t;
}
(** A statue that presses a switch: the player stands on [face_from], faces
    [facing] and presses A. The statue is the tile [statue_tile]. *)

(** How a switch is pressed. *)
type press =
  | Statues of statue list
      (** Each press flips it (Pokemon Mansion). The statues on this map only;
          non-empty. *)
  | Boulder_buttons of { buttons : Tile_pos.t list; set_value : int }
      (** A Strength boulder pushed onto one of [buttons] ([B] tiles) sets the
          switch's VAR to [set_value] for good (Victory Road). *)

type switch = {
  switch_name : string;
  switch_flag : string;
  floors : string list;
  press : press;
}
(** A switch the map's gates follow. One state is shared by every map in
    [floors] (an event flag or VAR named [switch_flag]); each floor redraws its
    gates when it loads. *)
