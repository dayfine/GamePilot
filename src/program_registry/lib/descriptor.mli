(** Types of a game and a registered program descriptor, shared by the per-game
    program lists and {!Program_registry}. *)

(** Where a program can run. *)
type backend =
  | Mgba  (** The mGBA emulator. *)
  | Switch  (** A Nintendo Switch console via capture card and PABotBase2. *)

(** Where the game picture sits in a Switch capture: the daemon's [--viewport]
    (daemon/src/viewport.h). *)
type viewport =
  | Nso_gba  (** A GBA game in the Switch's GBA app (FRLG). *)
  | Native  (** A full-screen Switch game, the whole frame. *)

(** The rules a program's checkpoint plans are written over, which pick the
    library that loads and runs them. *)
type rules =
  | Pokemon_grid
      (** The Pokémon grid rules (Pokemon_engine, the FRLG runner). *)
  | Plza_story  (** PLZA's story rules (Plza_engine, Plza_series). *)
  | Pokemon_home
      (** Pokémon HOME plans run from the Switch's HOME menu (Plza_engine,
          Plza_bank_home_series). *)
  | Plza_gifts
      (** PLZA's plans run from its main menu's Mystery Gift (Plza_engine,
          Plza_claim_gifts_series). *)
  | Bdsp_underground
      (** BDSP's Grand Underground checkpoint series (Bdsp_engine,
          Bdsp_underground_series). *)
  | Bdsp_static_rng
      (** BDSP's static legendary RNG checkpoint series (Bdsp_engine,
          Bdsp_static_rng_series). *)
  | Bdsp_battle_catch
      (** BDSP's standalone wild-battle catcher checkpoint series (Bdsp_engine,
          Bdsp_battle_catch_series). *)

(** Shared program grouping across games, shown by [gamepilot programs] and
    recorded in [run.json]. *)
type category =
  | Testing  (** Proofs of concept and bring-up harnesses. *)
  | Story  (** Story progression checkpoints. *)
  | Glitch_setup  (** Glitch activation, ACE setup, and ACE execution. *)
  | Farming  (** Repeatable supply, item, or training loops. *)
  | Dex_collection  (** Pokédex completion catches. *)
  | Shiny_hunting  (** RNG manipulation and shiny hunts. *)
  | Gifts  (** Mystery Gift claiming. *)
  | Storage  (** Pokémon HOME box transfers. *)

type switch = {
  title : string;  (** As the ctl usage names it: ["FireRed"]. *)
  home_tile : Switch.Home_screen.tile_color;
      (** Colour bounds of the game's tile on the Switch HOME menu. *)
  lab_panel : string;  (** ["PokemonFRLG:AutoStory"]. *)
}
(** A game on the lab's Switch: the title the HOME steps (park, resume,
    close-game, start-game, delete-save) go back to and look for by its tile's
    colour, and the lab app's program panel whose console setup has the
    controller board and capture card it runs with ([gamepilot switch-devices]).
*)

type game = {
  game_id : string;  (** ["frlg"], as plans and the games/ folder name it. *)
  game_name : string;  (** Full display name of the game. *)
  delete_save_icons : (string * string) list;
      (** Its Switch titles' icons on their "Delete Save Data for <user>" page
          (Switch.Delete_save), each a repo path, by the key
          [gamepilot ctl delete-save] takes: [firered] for FRLG. *)
  switch : switch option;
      (** [None] while none of its HOME tiles was measured. *)
}
(** A game known to GamePilot. *)

type t = {
  id : string;  (** [<game>.<program>]: ["frlg.mail_glitch"]. *)
  game : game;  (** The game this program belongs to. *)
  name : string;  (** Display name. *)
  category : category;  (** Shared group this program is listed under. *)
  description : string;  (** One line. *)
  doc : string;  (** Its page, from the repo root. *)
  checkpoints : string option;
      (** Its checkpoint plans' folder from the repo root; [None] for a one-shot
          program ([gamepilot run]). *)
  backends : backend list;  (** Backends this program supports. *)
  viewport : viewport;
      (** The Switch's game picture, which every daemon of its runs takes. *)
  rules : rules;  (** What its plans are written over. *)
  options : Run_options.declared list;
      (** The keys its runs take in [gamepilot run --options KEY=VALUE], each
          with the values it takes and a line of what it chooses; [[]]: none.
          [gamepilot programs] and its guide page's [options] block list them.
      *)
}
(** A registered program's descriptor. *)

val category_name : category -> string
(** Display name of a category, e.g. ["Glitch Setup"], ["Shiny Hunting"]. *)
