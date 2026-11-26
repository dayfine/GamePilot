(** Entering Pokémon Brilliant Diamond / Shining Pearl from a launched game to
    the overworld.

    Ported from the fork's
    [SerialPrograms/Source/PokemonBDSP/Programs/PokemonBDSP_GameEntry.cpp]
    ([openedgame_to_gamemenu], [gamemenu_to_ingame], [openedgame_to_ingame])
    with timings from [PokemonBDSP_Settings.cpp] ([ENTER_GAME_MASH0 = 5000 ms]).

    Where it differs deliberately: uses [Wire.A] (instead of [ZL]) to advance
    past the title screen, and bounds the load/enter waits to 60 s so a stuck
    boot fails cleanly. *)

val openedgame_to_ingame :
  log:(string -> unit) ->
  picture:Wire.box ->
  ?post_wait_ms:int ->
  unit ->
  (unit, string) result
(** From the black launch screen (or already on the title screen), wait for the
    opening/title to appear, mash A to enter the save, wait for the load-to-
    overworld black fade to finish, and wait [post_wait_ms] (default 1000 ms).
*)
