(** The [hello], [backend.load_state] and [backend.save_*] results: what the
    daemon drives and where its clock stands. *)

type json = Yojson.Safe.t
(** A decoded JSON value: a result object. *)

type backend = {
  kind : string;  (** the backend: ["mgba"], ["switch"] or ["view"] *)
  game_code : string;
      (** the ROM's game code on mGBA (["BPRE"] is FireRed); empty on the Switch
          and view backends *)
  frame_rate : float;  (** frames per second *)
  width : int;
  height : int;  (** the frame's size in pixels *)
  viewport : Probe.box;
      (** where the game picture sits in the frame, normalized to it; probe
          boxes are relative to this *)
  game_width : int;
  game_height : int;
      (** the picture's native size in game pixels ([game_size] on the wire);
          templates are in these *)
}
(** What the daemon drives, from [hello]: the backend, the game, the frame's
    size and where the game picture sits in it. *)

type hello_result = {
  protocol : int;  (** the protocol's major version, [1] *)
  daemon : string;  (** its name and version, e.g. ["gamepilot-daemon/0.1"] *)
  backend : backend;
  probe_kinds : string list;
      (** every probe kind it runs, e.g. ["core.color_stats@1"] *)
}
(** The daemon's answer to [hello]: what it speaks, what it is, what it drives
    and which probes it can run. *)

val hello_result_of_json : json -> hello_result
(** The [hello] result; a missing or mistyped field is a [Decode_error]. *)

val json_of_hello_result : hello_result -> json
(** The [hello] result, as {!hello_result_of_json} reads it. *)

type load_state_result = { seq : int; load : int }
(** The answer to [backend.load_state] (and [backend.reset]): the frame [seq]
    after loading, and [load], how many loads and resets have succeeded on this
    daemon, this one included. Frames carry the count, so a reader can tell the
    frames from before a load. *)

val load_state_result_of_json : json -> load_state_result
(** The [backend.load_state] result; a missing field is a [Decode_error]. *)

val json_of_load_state_result : load_state_result -> json
(** The [backend.load_state] result, as {!load_state_result_of_json} reads it.
*)

val save_result_of_json : json -> int
(** [{"seq": n}], the answer to [backend.save_state] and [backend.save_frame].
*)

val json_of_save_result : int -> json
(** [{"seq": n}], as {!save_result_of_json} reads it. *)
