(** The programs GamePilot can run, as PA/CC's program list has them: each under
    its game and a group path, with a name, a one-line description and a doc
    page (the fork's [ProgramDescriptor] in
    SerialPrograms/Source/CommonFramework/Panels/PanelDescriptor.h: category,
    display name, description, doc link). Unlike the fork, nothing registers
    itself at start-up: {!all} is a plain list, and a new program is one more
    entry in it (docs/programs/README.md).

    What a program needs of the save (free party slots, field moves) is not
    declared here: it is derived from its checkpoint plans, as the pre-flight
    does ([gamepilot programs] prints it). *)

type backend = Mgba | Switch

(** Where the game picture sits in a Switch capture: the daemon's [--viewport]
    (daemon/src/viewport.h). [Nso_gba]: a GBA game in the Switch's GBA app
    (FRLG); [Native]: a full-screen Switch game, the whole frame. *)
type viewport = Nso_gba | Native

(** How a program's checkpoint ids order its chain. [Parts_first]: a checkpoint
    split in two runs its lettered part first, [cp-05a] then [cp-05], as the
    FRLG fork splits them (Engine_series.Checkpoint_order). [Name_order]: plain
    name order, where a lettered id continues the bare one: PLZA's 01.00b,
    03.02b and 03.03b, 03.03c follow 01.00a, 03.02 and 03.03 (the checkpoint
    rows of the PLZA fork's PokemonLZA_AutoStoryPlan.h, its plan sources saying
    where each starts). *)
type checkpoint_order = Parts_first | Name_order

type game = {
  game_id : string;  (** ["frlg"], as plans and the games/ folder name it. *)
  game_name : string;
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
  checkpoint_order : checkpoint_order;
}

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

val run_fields : t -> (string * string) list
(** What a run's run.json says of its program: [game], [game_name], [program]
    (the id), [program_name], [group] (its parts joined by [" / "]). *)
