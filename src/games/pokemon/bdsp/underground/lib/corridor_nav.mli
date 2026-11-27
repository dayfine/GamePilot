(** Corridor-patrol navigation and doorway-bounce refresh loop for BDSP Grand
    Underground shard farming.

    Rather than requiring full tile-grid maps of the Grand Underground, the loop
    anchors at a single Pokémon Hideaway doorway in a straight corridor: 1.
    Pulse R (radar) and read golden sparkle offsets on the minimap. 2.
    Walk/slide along the corridor wall to each sparkle and run the minigame. 3.
    Step into the Hideaway doorway and immediately back out to respawn dig spots
    without running deep into the cave (avoiding wild Pokémon, with a
    battle-escape fallback if one spawns near the doorway). 4. Save every
    [save_every] digs and stop once the {!Mining_goal.goal} is met. *)

type sparkle_target = {
  offset_tiles : int;  (** Distance along the corridor from the anchor. *)
  wall_side : Grid_geometry.Direction.t;
      (** Which wall side to face and press A against. *)
}
(** One dig-spot target detected along a corridor wall. *)

type doorway_anchor = {
  enter_dir : Grid_geometry.Direction.t;
      (** Direction to step into the Hideaway. *)
  exit_dir : Grid_geometry.Direction.t;
      (** Opposite direction to step back into the tunnel. *)
}
(** Hideaway doorway directions used to refresh dig spots. *)

(** Result of walking toward a corridor dig spot. *)
type walk_outcome =
  | At_wall  (** Reached the sparkling wall cleanly. *)
  | Wild_battle  (** Interrupted by a wild Pokémon encounter. *)

(** Result of bouncing through a Hideaway doorway. *)
type refresh_outcome =
  | Refreshed  (** Entered and exited cleanly; dig spots respawned. *)
  | Refresh_wild_battle  (** A wild battle triggered near the doorway. *)

type game_steps = {
  pulse_radar : unit -> (sparkle_target list, string) result;
      (** Pulse R and list reachable dig spots in the corridor. *)
  walk_to_sparkle : sparkle_target -> (walk_outcome, string) result;
      (** Walk to [target] and face the wall. *)
  dig_wall : unit -> (Mining_goal.item list * bool, string) result;
      (** Play the mining minigame, returning [(uncovered_items, bailed)]. *)
  bounce_hideaway_door : doorway_anchor -> (refresh_outcome, string) result;
      (** Step into the Hideaway doorway and immediately back out. *)
  run_from_battle : unit -> (unit, string) result;
      (** Escape a wild Pokémon encounter. *)
  save_game : unit -> (unit, string) result;  (** Save progress periodically. *)
}
(** What {!run_session} reads and does in the game. *)

type session_summary = {
  tally : Mining_goal.tally;  (** Shards, digs, and bail counts. *)
  refreshes : int;  (** Number of Hideaway doorway refreshes executed. *)
  battles_escaped : int;  (** Number of wild battles escaped. *)
  saves : int;  (** Number of periodic saves performed. *)
}
(** Final statistics returned when {!run_session} satisfies its goal. *)

val run_session :
  goal:Mining_goal.goal ->
  anchor:doorway_anchor ->
  save_every:int ->
  max_refreshes:int ->
  steps:game_steps ->
  (session_summary, string) result
(** Run the doorway-anchored corridor loop until [goal] is met or
    [max_refreshes] is reached (returning [Error] on step failure or if
    [max_refreshes] is exhausted without meeting the goal). *)
