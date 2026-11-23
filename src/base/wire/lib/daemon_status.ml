open Json_fields

type json = Yojson.Safe.t
type thread = { name : string; seq : int; t_ms : float }

type t = {
  t_ms : float;
  backend : string;
  client : string option;
  fidelity : string;
  threads : thread list;
  ring_depth : int;
  ring_capacity : int;
  gaps : int;
  gap_frames : int;
}

let what = "status.result"

let thread_of_json j =
  let what = what ^ ".threads" in
  {
    name = string_field what "name" j;
    seq = int_field what "seq" j;
    t_ms = float_field what "t_ms" j;
  }

let json_of_thread ({ name; seq; t_ms } : thread) =
  `Assoc [ ("name", `String name); ("seq", `Int seq); ("t_ms", `Float t_ms) ]

let client_of_json = function
  | `Null -> None
  | j -> Some (to_string (what ^ ".client") j)

let of_json j =
  let ring = field what "ring" j and gaps = field what "gaps" j in
  {
    t_ms = float_field what "t_ms" j;
    backend = string_field what "backend" j;
    client = client_of_json (field what "client" j);
    fidelity = string_field what "fidelity" j;
    threads = List.map thread_of_json (list_field what "threads" j);
    ring_depth = int_field (what ^ ".ring") "depth" ring;
    ring_capacity = int_field (what ^ ".ring") "capacity" ring;
    gaps = int_field (what ^ ".gaps") "count" gaps;
    gap_frames = int_field (what ^ ".gaps") "frames" gaps;
  }

let to_json s =
  `Assoc
    [
      ("t_ms", `Float s.t_ms);
      ("backend", `String s.backend);
      ("client", match s.client with Some c -> `String c | None -> `Null);
      ("fidelity", `String s.fidelity);
      ("threads", `List (List.map json_of_thread s.threads));
      ( "ring",
        `Assoc
          [ ("depth", `Int s.ring_depth); ("capacity", `Int s.ring_capacity) ]
      );
      ("gaps", `Assoc [ ("count", `Int s.gaps); ("frames", `Int s.gap_frames) ]);
    ]

let stuck_limit_ms = 2000.
let age_ms (s : t) (thread : thread) = s.t_ms -. thread.t_ms
let stuck s = List.filter (fun th -> age_ms s th > stuck_limit_ms) s.threads
