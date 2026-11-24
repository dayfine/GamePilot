open Json_fields

type json = Yojson.Safe.t
type t = { owner : string; client : string; held_ms : int; ttl_ms : int }

let what = "lease"

let of_json j =
  {
    owner = string_field what "owner" j;
    client = string_field what "client" j;
    held_ms = int_field what "held_ms" j;
    ttl_ms = int_field what "ttl_ms" j;
  }

let to_json { owner; client; held_ms; ttl_ms } =
  `Assoc
    [
      ("owner", `String owner);
      ("client", `String client);
      ("held_ms", `Int held_ms);
      ("ttl_ms", `Int ttl_ms);
    ]

let acquire_result_of_json j = of_json (field "lease.acquire" "lease" j)
let json_of_acquire_result t = `Assoc [ ("lease", to_json t) ]

let release_result_of_json j =
  match field "lease.release" "released" j with
  | `Bool b -> b
  | _ -> fail "lease.release.released: expected a bool"

let json_of_release_result b = `Assoc [ ("released", `Bool b) ]
let held_code = -32004

let refusal (e : Jsonrpc.error) =
  match e.data with
  | Some data when e.code = held_code -> (
      try Some (of_json data) with Decode_error _ -> None)
  | _ -> None

let ms_per_s = 1000

let describe t =
  let who =
    if t.client = "" || t.client = t.owner then t.owner
    else Printf.sprintf "%s (%s)" t.owner t.client
  in
  Printf.sprintf "%s, held %d s" who (t.held_ms / ms_per_s)
