(** The Pokémon grid rules' own flags, which the generic series flags carry
    (Run_flags: [series Run_flags.flags]): [gamepilot run --plan]'s, which a
    series' runs share, and the series' --make-room. *)

type checkpoint_flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
  end_check_only : bool;
  grind_cap : int option;
}
(** [gamepilot run --plan PLAN.json]'s flags. *)

val checkpoint_defaults : checkpoint_flags
(** No state, log or party; the program's default port; running. *)

type series = { common : checkpoint_flags; make_room : string option }
(** A series' Pokémon flags: --party, --center, --walk, --end-check-only and
    --grind-battles for its runs ([common]; their port is the series' --port),
    and --make-room MAP. *)

type flags = series Run_flags.flags
(** [gamepilot run]'s flags over the Pokémon grid rules. *)

val series : series Run_flags.game_flags
(** The hooks that parse a series' Pokémon flags. *)

val defaults : flags
(** {!Run_flags.defaults} with no Pokémon flag given. *)

val parse : flags -> string list -> (flags, string) result
(** {!Run_flags.parse} with the Pokémon flags. *)

val usage : string
(** [gamepilot run]'s usage lines. *)
