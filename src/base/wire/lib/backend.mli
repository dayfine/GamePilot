(** The [hello], [backend.load_state] and [backend.save_*] results: what the
    daemon drives and where its clock stands. *)

type json = Yojson.Safe.t

type backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
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

type hello_result = {
  protocol : int;
  daemon : string;
  backend : backend;
  probe_kinds : string list;
}

val hello_result_of_json : json -> hello_result
val json_of_hello_result : hello_result -> json

type load_state_result = { seq : int; load : int }

val load_state_result_of_json : json -> load_state_result
val json_of_load_state_result : load_state_result -> json

val save_result_of_json : json -> int
(** [{"seq": n}], the answer to [backend.save_state] and [backend.save_frame].
*)

val json_of_save_result : int -> json
