(** Pure JSON API and launch command builders for the local [gamepilot ui] hub
    (design: [docs/design/Release-and-Onboarding.md]).

    Serializes {!Program_registry.all} and {!Console_config.t} for the browser
    dashboard, validates launch requests against {!Program_registry}, and builds
    the exact [gamepilot run] argv list that the hub dispatches. *)

type launch_request = {
  console_id : string;  (** Configured console id from [consoles.json]. *)
  program_id : string;  (** Registered program id (e.g. ["frlg.supplies"]). *)
  from_id : string option;  (** Optional [--from] checkpoint id. *)
  to_id : string option;  (** Optional [--to] checkpoint id. *)
  mode : string option;
      (** Optional [--mode] (["testing"] or ["verification"]); [None] uses the
          program's default live behavior. *)
  preflight : bool;  (** True to run [--preflight] instead of executing. *)
  options : (string * string) list;  (** Program [--options KEY=VALUE] pairs. *)
}
(** A run or preflight request submitted by the UI. *)

val checkpoints_of : Program_registry.t -> string list
(** Sorted checkpoint IDs discovered in a program's bundled plan directory. *)

val programs_json : unit -> Yojson.Safe.t
(** JSON payload for [GET /api/programs], derived directly from
    {!Program_registry.all} and {!Run_options.declared}. *)

val devices_json : unit -> Yojson.Safe.t
(** JSON payload for [GET /api/devices], listing discovered serial ports and
    capture devices on the host. *)

val consoles_json :
  ?path:string ->
  active_run:(Console_config.console -> Yojson.Safe.t option) ->
  unit ->
  (Yojson.Safe.t, string) result
(** JSON payload for [GET /api/consoles], combining [consoles.json], serial
    device presence, and any active (hub-launched or external) run per console.
*)

val decode_console_upsert :
  Yojson.Safe.t -> (Console_config.console, string) result
(** Decodes a [POST /api/consoles] JSON body into a {!Console_config.console}.
*)

val decode_launch : Yojson.Safe.t -> (launch_request, string) result
(** Decodes a [POST /api/runs] JSON body into a {!launch_request}. *)

val build_run_argv :
  gamepilot:string ->
  ?listen:string ->
  ?runs_dir:string ->
  console:Console_config.console ->
  launch_request ->
  (string list, string) result
(** Validates [launch_request] against {!Program_registry} and builds the
    [gamepilot run ...] argv list to execute. When [listen] is set and not
    ["127.0.0.1"], appends [--listen] alongside [--watch] so LAN clients can
    reach the daemon's watch page. When [runs_dir] is set and non-empty, appends
    [--runs-dir] so spawned runs write under the hub's runs directory. *)

val extract_watch_url : string -> string option
(** Extracts the first [http://...] URL from a child process log line, if any.
*)

val split_http : string -> (string * string * string) option
(** Splits a raw HTTP/1.1 request into [(method, path, body)]. *)

val status_text : int -> string
(** Standard HTTP reason phrase for a status code returned by the hub. *)

val stop_id_of_path : string -> string option
(** Extracts [id] from a [/api/runs/<id>/stop] request path. *)
