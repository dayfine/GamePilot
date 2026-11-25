(** What a Pokémon checkpoint promises ({!Pokemon_terms.Postconditions}) as
    text. *)

open Pokemon_terms

val text : Postconditions.t -> string list
(** One line per promise: ["position CeladonCity (39, 21) south"],
    ["party includes blastoise, pidgey"], ["coins gained 20"],
    ["money spent 4100"], ["flags a, b"], ["mr-mime knows psychic"],
    ["mr-mime at least Lv 33"], ["marks mail, none"]. *)
