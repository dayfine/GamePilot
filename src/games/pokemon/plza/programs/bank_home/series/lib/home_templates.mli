(** The PNG templates Pokémon HOME's steps on Legends: Z-A find their way by
    ({!Plza_bank_home.Bank_home_game.templates}), read from the repo: Pokémon
    HOME's tile art and title, its box counter's "/300" and digits
    ([src/pokemon/home/assets/], [box-digit-<d>.png] for each digit cut so far),
    PLZA's icon on HOME's game list and its title over the Switch's tile row
    ([src/games/pokemon/plza/assets/]). *)

val load : unit -> (Plza_bank_home.Bank_home_game.templates, string) result
(** Every template; [Error] naming the first file not found from here. A missing
    digit is a digit without a template ({!Pokemon_home.Box_view.complete}), not
    an error. *)
