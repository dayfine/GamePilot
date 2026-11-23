let default_port = 47900

(* How long the reader waits on the socket before reporting [Idle]. *)
let idle_poll_s = 0.05
let recv_chunk = 65536
let ms_per_s = 1000.

(* The queue between the reader thread and the program's thread. *)
type queue = {
  events : Session.event Queue.t;
  mutex : Mutex.t;
  nonempty : Condition.t;
}

let push q ev =
  Mutex.protect q.mutex (fun () ->
      Queue.push ev q.events;
      Condition.signal q.nonempty)

let push_idle q =
  Mutex.protect q.mutex (fun () ->
      if Queue.is_empty q.events then (
        Queue.push Session.Idle q.events;
        Condition.signal q.nonempty))

let pop q =
  Mutex.protect q.mutex (fun () ->
      while Queue.is_empty q.events do
        Condition.wait q.nonempty q.mutex
      done;
      Queue.pop q.events)

let push_line q line =
  match Wire.message_of_string line with
  | m -> push q (Session.Message m)
  | exception Wire.Decode_error e ->
      push q (Session.Closed ("bad message from daemon: " ^ e))

(* Splits [buf] at newlines; parses and pushes every complete line. *)
let drain_lines q buf =
  let s = Buffer.contents buf in
  let rec go start =
    match String.index_from_opt s start '\n' with
    | None -> start
    | Some nl ->
        let line = String.trim (String.sub s start (nl - start)) in
        if line <> "" then push_line q line;
        go (nl + 1)
  in
  let consumed = go 0 in
  Buffer.clear buf;
  Buffer.add_string buf (String.sub s consumed (String.length s - consumed))

(* Reads what the socket has; [false] once the daemon closed it. *)
let receive fd q buf chunk =
  match Unix.recv fd chunk 0 recv_chunk [] with
  | 0 ->
      push q (Session.Closed "daemon closed the connection");
      false
  | n ->
      Buffer.add_subbytes buf chunk 0 n;
      drain_lines q buf;
      true

(* Waits for data, reporting [Idle] after [idle_poll_s] without any. *)
let read_ready fd q buf chunk =
  match Unix.select [ fd ] [] [] idle_poll_s with
  | [], _, _ ->
      push_idle q;
      true
  | _ -> receive fd q buf chunk

let reader fd q stop =
  let buf = Buffer.create recv_chunk and chunk = Bytes.create recv_chunk in
  let rec loop () =
    if (not (Atomic.get stop)) && read_ready fd q buf chunk then loop ()
  in
  try loop ()
  with Unix.Unix_error (e, _, _) ->
    if not (Atomic.get stop) then
      push q (Session.Closed ("socket: " ^ Unix.error_message e))

let rec send_all fd b off len =
  if len > 0 then
    let n = Unix.send fd b off len [] in
    send_all fd b (off + n) (len - n)

let run ?(port = default_port) f =
  (* A closed socket must raise, not kill the process (no SIGPIPE on Windows). *)
  (try Sys.set_signal Sys.sigpipe Sys.Signal_ignore
   with Invalid_argument _ -> ());
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt fd Unix.TCP_NODELAY true;
  (try Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_loopback, port))
   with e ->
     Unix.close fd;
     raise e);
  let q =
    {
      events = Queue.create ();
      mutex = Mutex.create ();
      nonempty = Condition.create ();
    }
  in
  let stop = Atomic.make false in
  let thread = Thread.create (fun () -> reader fd q stop) () in
  let send m =
    let b = Bytes.of_string (Wire.string_of_message m ^ "\n") in
    send_all fd b 0 (Bytes.length b)
  in
  let transport =
    {
      Session.send;
      recv = (fun () -> pop q);
      wall_ms = (fun () -> Unix.gettimeofday () *. ms_per_s);
    }
  in
  Fun.protect
    ~finally:(fun () ->
      Atomic.set stop true;
      Thread.join thread;
      Unix.close fd)
    (fun () -> Session.run transport f)
