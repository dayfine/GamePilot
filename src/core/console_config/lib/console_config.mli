(** Named console configurations stored in [consoles.json] under the per-user
    GamePilot config directory (design:
    [docs/design/Release-and-Onboarding.md]).

    Maps a short console id (such as ["console-a"] or ["mgba"]) to its backend
    and device parameters so [gamepilot run ... --console <id>],
    [gamepilot setup], [gamepilot doctor], and the local UI share one source of
    truth without repeating [--backend], [--serial], or [--capture] flags. *)

(** How GamePilot drives a console. *)
type backend =
  | Switch of {
      serial : string option;
          (** Controller serial port (e.g. ["/dev/cu.usbserial-..."] or
              ["COM3"]); [None] for capture-only / dry-run setups. *)
      capture : string;  (** Capture card device name or index. *)
    }
      (** A Nintendo Switch driven through a controller board and capture card.
      *)
  | Mgba of { port : int  (** mGBA bridge TCP port (default 47810). *) }
      (** A local mGBA emulator instance connected over its Lua bridge. *)

type console = {
  id : string;
      (** Short identifier for [--console ID] (lowercase, digits, [-], [_]). *)
  name : string;  (** Display label (e.g. ["Console A"]). *)
  backend : backend;  (** Backend and device settings for this console. *)
}
(** One configured console entry in [consoles.json]. *)

type t = console list
(** All configured consoles in display order. *)

val default_mgba_port : int
(** Default mGBA bridge port (47810). *)

val default_path : unit -> string
(** Default path to [consoles.json]:
    [Repo_io.Repo_files.data_dir "GAMEPILOT_CONFIG" "config" / "consoles.json"].
*)

val valid_id : string -> bool
(** Whether [id] is non-empty and uses only lowercase ASCII letters, digits,
    ['-'], or ['_']. *)

val of_json : Yojson.Safe.t -> (t, string) result
(** Decodes a [consoles.json] object ([{"consoles": [...]}]). *)

val to_json : t -> Yojson.Safe.t
(** Encodes [t] as a [consoles.json] object. *)

val load : ?path:string -> unit -> (t, string) result
(** Reads [consoles.json] from [path] (default {!default_path}); returns [Ok []]
    when the file does not exist. *)

val save : ?path:string -> t -> (unit, string) result
(** Writes [consoles.json] to [path] (default {!default_path}), creating parent
    directories as needed. *)

val find : t -> string -> console option
(** Finds a console by its [id]. *)

val upsert : t -> console -> t
(** Replaces the console with the same [id], or appends it if new. *)

val remove : t -> string -> t * bool
(** Removes the console with [id]; returns the updated list and whether an entry
    was removed. *)

val to_run_args : console -> string list
(** CLI flags corresponding to [console] ([--backend], [--capture], [--serial]
    or [--mgba-port]). *)

val expand_console_flag :
  ?path:string -> string list -> (string list, string) result
(** Expands [--console ID] in a [gamepilot run] flag list by prepending
    {!to_run_args} for [ID] (so any explicit flags after it still override).
    Leaves flag lists without [--console] unchanged. *)

val describe : console -> string
(** One-line human-readable summary of [console]. *)
