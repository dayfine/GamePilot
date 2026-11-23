(** What one look at the screen shows, as a game's readers report it. The scene
    rules ({!Talk_over}, {!Settle}) read only these facts, never a game's
    detectors, so every game shares them. *)

type t = {
  fade : Fade.t;
  banner : bool;  (** the location banner of the map the step expects *)
  dialog : bool;  (** a dialogue box shows *)
  battle : bool;  (** a battle shows (its menu, its HUD or its opening) *)
  free_control : bool;  (** the overworld, with the player in control *)
  screen_still : bool;  (** the screen barely changed since the last frame *)
  player_still : bool;  (** the box around the player barely changed *)
}

val none : t
(** Nothing seen: no fade, every flag false. *)
