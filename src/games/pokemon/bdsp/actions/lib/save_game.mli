(** Reusable in-game save action for Pokémon BDSP ([X -> R -> A]).

    Mirrors FRLG's {!Frlg_actions.Game_save}: shared across all BDSP programs
    (Grand Underground farming, RNG manipulation, Ramanas Park, and future
    AutoStory checkpoints). *)

val save_game :
  log:(string -> unit) -> picture:Wire.box -> unit -> (unit, string) result
(** Open the X menu, press [R] (Save), confirm with [A], wait for the save write
    to finish, and clear any leftover dialog box. *)
