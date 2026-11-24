(** {!Grind}'s live rig, moved unchanged out of {!Story_game}: the party read
    and swapped through the menus (the reckoned party kept in step), moves and
    the level read on the summary ({!Member_level}), walks and battles the story
    game's, and a heal that walks to the nurse and talks to her, or steps on the
    heal pad. *)

val make :
  log:(string -> unit) ->
  party:Party_roster.t ref ->
  walk_to:(Story.Pose.grid -> (unit, Story.Failure.cause) result) ->
  find_battle:(unit -> unit) ->
  battle:(Frlg_battle.Battle_script.t -> Frlg_battle.Scripted_battle.outcome) ->
  Grind.rig
