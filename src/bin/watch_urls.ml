(* Where a run's watch page and the hub are, as the runner prints them
   (docs/design/Watch-Page.md): on this machine, and, when the page listens
   beyond it, from another device on the LAN (with Stop's token in the run's
   URL). *)

let hub_port = 47901
let local = "127.0.0.1"
let listen_env = "GAMEPILOT_WATCH_LISTEN"

(* --listen's default: $GAMEPILOT_WATCH_LISTEN (the runner's env file may set
   it to 0.0.0.0), else this machine only. *)
let default_listen () =
  match Sys.getenv_opt listen_env with
  | Some address when address <> "" -> address
  | _ -> local

let token_bytes = 16

(* Stop's token for a series: 32 random hex digits. *)
let new_token () =
  let random = Random.State.make_self_init () in
  String.concat ""
    (List.init token_bytes (fun _ ->
         Printf.sprintf "%02x" (Random.State.int random 256)))

(* A documentation address (TEST-NET-1): connecting a UDP socket to it sends
   nothing but picks the interface of the default route. *)
let probe_address = "192.0.2.1"
let probe_port = 9

let interface_address socket =
  Unix.connect socket
    (Unix.ADDR_INET (Unix.inet_addr_of_string probe_address, probe_port));
  match Unix.getsockname socket with
  | Unix.ADDR_INET (address, _) when address <> Unix.inet_addr_any ->
      Some (Unix.string_of_inet_addr address)
  | _ -> None

(* This machine's address on the LAN, if it has one. *)
let lan_address () =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close socket)
    (fun () -> try interface_address socket with Unix.Unix_error _ -> None)

let url ?token host port =
  Printf.sprintf "http://%s:%d/%s" host port
    (match token with Some t -> "?token=" ^ t | None -> "")

(* The hub's address that always opens the newest live run: one to bookmark. *)
let live_url host = Printf.sprintf "http://%s:%d/live" host hub_port

(* The page's address for this machine and, listening beyond it, for others. *)
let print ~listen ~token ~port =
  Printf.printf
    "[Watch] this run: %s\n[Watch] all runs: %s (newest live run: %s)\n"
    (url local port) (url local hub_port) (live_url local);
  if listen <> local then (
    let host =
      if listen = "0.0.0.0" then
        Option.value (lan_address ()) ~default:"<this machine's address>"
      else listen
    in
    Printf.printf
      "[Watch] from another device (with Stop): %s\n\
       [Watch] all runs from another device: %s (newest live run: %s)\n\
       [Watch] anyone on the network can watch; Stop needs the token above\n"
      (url ~token host port) (url host hub_port) (live_url host);
    flush stdout)
