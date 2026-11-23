(** The [hello] and [backend.load_state] results: what the daemon drives and
    where its clock stands. *)

type json = Yojson.Safe.t

type backend = {
  kind : string;
  game_code : string;
  frame_rate : float;
  width : int;
  height : int;
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
