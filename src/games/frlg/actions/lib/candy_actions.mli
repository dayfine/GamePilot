(** The Rare Candy game actions as plan handlers: ["use_rare_candy"] (one candy,
    {!Rare_candy} on {!Rare_candy_steps}) and ["candy_level"] ({!Candy_level}),
    their args read by {!Candy_plan}. The member is found by its species or slot
    in the reckoned party ({!Party_roster}); after an evolution the party is
    updated with the species read on the summary.

    ["use_rare_candy"] logs the level read after the candy ({!Member_level}),
    the moves it learned and declined and the evolution. It fails as
    [out_of_candies] or [rare_candy_failed], or as a menu step's cause. *)

val handlers :
  log:(string -> unit) ->
  party:Party_roster.t ref ->
  (string * Pokemon_engine.Game.game_action) list
