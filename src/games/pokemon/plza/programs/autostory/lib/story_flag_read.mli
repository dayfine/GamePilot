(** The story flags a checkpoint promises at its end
    ([metadata.postconditions.flags], {!Plza_rules.readable_flags}), read from
    the game there, for the runner's end check and its "already at its end"
    pre-pass ({!Engine_run.Runner}).

    - [mystery_gift]: the main menu's sixth row, Link Play (通信で遊ぶ), shows only
      once Mable's research reward is claimed (03.15-mable-reward), which also
      unlocks Mystery Gift. The menu is opened ({!Plza_story.Main_menu_visit}),
      the row read ({!Plza_story.Steps.game_steps.read_link_play_row}) and the
      menu closed. No passive read tells the end of 03.15 apart: no minimap
      indoors, and Mable's office looks the same after her talk as after her
      reward, where a reload can land.

    Each read is logged as
    ["[Checkpoint] <id>: FLAG READ: mystery_gift set (the main menu shows Link
     Play)"], or ["clear (...)"], or ["FLAG UNREAD: mystery_gift: <why>"]. Ours:
    the fork checks no end. *)

val read :
  Plza_story.Steps.game_steps ->
  checkpoint_id:string ->
  string list ->
  (string * bool) list
(** Each flag read, set or clear; a flag that could not be read (no menu, or the
    menu not closed again) or that PLZA does not read is left out, so its
    promise is not checked. *)
