(** The programs GamePilot can run, as PA/CC's program list has them: each under
    its game and a group path, with a name, a one-line description and a doc
    page (the fork's [ProgramDescriptor] in
    SerialPrograms/Source/CommonFramework/Panels/PanelDescriptor.h: category,
    display name, description, doc link). Unlike the fork, nothing registers
    itself at start-up: {!all} is a plain list, and a new program is one more
    entry in it (docs/guide/README.md, "Adding a program").

    What a program needs of the save (free party slots, field moves) is not
    declared here: it is derived from its checkpoint plans, as the pre-flight
    does ([gamepilot programs] prints it). *)

type backend = Mgba | Switch

(** Where the game picture sits in a Switch capture: the daemon's [--viewport]
    (daemon/src/viewport.h). [Nso_gba]: a GBA game in the Switch's GBA app
    (FRLG); [Native]: a full-screen Switch game, the whole frame. *)
type viewport = Nso_gba | Native

(** The rules a program's checkpoint plans are written over, which pick the
    library that loads and runs them. [Pokemon_grid]: the Pokémon grid rules
    (Pokemon_engine, the FRLG runner); [Plza_story]: PLZA's story rules
    (Plza_engine, Plza_series); [Plza_home]: PLZA's plans run from the Switch's
    HOME menu in Pokémon HOME (Plza_engine, Plza_bank_home_series). *)
type rules = Pokemon_grid | Plza_story | Plza_home

type switch_home = {
  title : string;  (** As the ctl usage names it: ["FireRed"]. *)
  home_tile : Switch_home.Home_screen.tile_color;
  lab_panel : string;  (** ["PokemonFRLG:AutoStory"]. *)
}
(** A game on the lab's Switch: the title the HOME steps (park, resume,
    close-game, start-game, delete-save) go back to and look for by its tile's
    colour, and the lab app's program panel whose console setup has the
    controller board and capture card it runs with ([gamepilot switch-devices]).
*)

type game = {
  game_id : string;  (** ["frlg"], as plans and the games/ folder name it. *)
  game_name : string;
  delete_save_icons : (string * string) list;
      (** Its Switch titles' icons on their "Delete Save Data for <user>" page
          (Switch_home.Delete_save), each a repo path, by the key
          [gamepilot ctl delete-save] takes: [firered] for FRLG. *)
  switch_home : switch_home option;
      (** [None] while none of its HOME tiles was measured. *)
}

type t = {
  id : string;  (** [<game>.<program>]: ["frlg.mail_glitch"]. *)
  game : game;
  name : string;  (** Display name. *)
  group : string list;  (** Where it is listed: [["FRLG"; "Glitches"]]. *)
  description : string;  (** One line. *)
  doc : string;  (** Its page, from the repo root. *)
  checkpoints : string option;
      (** Its checkpoint plans' folder from the repo root; [None] for a one-shot
          program ([gamepilot run]). *)
  backends : backend list;
  viewport : viewport;
      (** The Switch's game picture, which every daemon of its runs takes. *)
  rules : rules;  (** What its plans are written over. *)
  options : Run_options.declared list;
      (** The keys its runs take in [gamepilot run --options KEY=VALUE], each
          with the values it takes and a line of what it chooses; [[]]: none.
          [gamepilot programs] and its guide page's [options] block list them.
      *)
}

val games : game list
(** Every game with a program or a Switch title GamePilot knows, PLZA (no
    program yet) first, as [gamepilot ctl delete-save] lists their keys. *)

val lab_game : string option -> (game * switch_home, string) result
(** The game the lab's console runs, by its id; with none, the one game that has
    Switch HOME data. An unknown id, a game without it, or (no id) not exactly
    one such game is an error naming the ids to pick from. *)

val lab_game_of_env : unit -> (game * switch_home, string) result
(** {!lab_game} of $GAMEPILOT_LAB_GAME (unset or empty: none). *)

val all : t list
(** By game, then group, then name. *)

val find : string -> t option
(** By id, or by the part after the game ([start_menu_poc]) when only one
    program has it. *)

val of_plan_dir : string -> t option
(** The program whose checkpoints folder this is: the folder's path (absolute or
    relative, with or without a trailing [/]) ends with the program's. *)

val of_checkpoint : string -> t option
(** The program with a plan for this checkpoint id ([04-grind-farfetchd] is the
    Mail Glitch's), its folder found from the working directory up. *)

val locate : string -> string option
(** A repo path ({!t.doc}, {!t.checkpoints}) on this machine, found from the
    working directory up. *)

val backend_name : backend -> string
(** [mgba], [switch]: as [--backend] takes it. *)

val viewport_name : viewport -> string
(** [nso-gba], [native]: as the daemon's [--viewport] takes it. *)

val check_viewport : t option -> string option -> (string option, string) result
(** The daemon's [--viewport] for a run: the program's ({!viewport_name}), or
    the [--viewport] given when no program is known. A given one that differs
    from the program's is an error. [None]: neither, the daemon's default. *)

val check_options :
  t option -> (string * string) list -> (Run_options.t, string) result
(** A run's [--options] pairs ({!Run_options.check}) against the program's
    {!t.options}, before anything runs; with no program (a plan folder no
    program registers) any option is refused. *)

val run_fields : t -> (string * string) list
(** What a run's run.json says of its program: [game], [game_name], [program]
    (the id), [program_name], [group] (its parts joined by [" / "]). *)
