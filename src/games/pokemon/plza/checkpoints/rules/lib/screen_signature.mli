(** What the screen shows where a checkpoint starts or ends, as a plan names it
    (its [execution.start_signature], or its postconditions' [place]): any of
    [talk_prompt] (an A prompt shows), [wild_zone] (the map's pin is in Wild
    Zone 1), [near_rocks] (the map's pin is on Taunie's rocks), [party] (the
    party bar's filled slots) and [minimap] (a recorded minimap's name). The
    same record is what was read. Pure: the reading is the autostory's
    [Start_signature] (from the fork's PokemonLZA_AutoStory.cpp start
    signature). *)

type t = {
  talk_prompt : bool option;
  wild_zone : bool option;
  near_rocks : bool option;
  party : int option;
  minimap : string option;
}
(** Each field named, or read; [None] when not. *)

val nothing : t
(** No field: a plan that names nothing, or a frame with nothing read (a fade, a
    text box). *)

val to_string : t -> string
(** ["no talk prompt, party 2, minimap after-taunie-battle"], or
    ["nothing read"]. *)

val confirmed : known:t -> t -> bool
(** Every field [known] names reads the same, and something was read. *)
