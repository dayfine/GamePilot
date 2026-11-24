(* An await's timeout is game time: the frames' t_ms, which the daemon keeps
   in game time at any speed (contracts v1.10). At 4x the timeout ends after a
   quarter of its wall time; on an emulator slower than real time it waits
   past its wall time while frames still come. *)

let hello_result =
  {|{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"mgba","game_code":"BPRE","frame_rate":59.7275,"width":240,"height":160,"viewport":{"x":0,"y":0,"w":1,"h":1},"game_size":{"width":240,"height":160}},"probe_kinds":[]}|}

let frame_ms = 1000. /. 59.7275

type case = { name : string; input : input; expect : expectation }
and input = { speed : float; timeout_ms : int }
and expectation = { wall_ms : float }

let cases =
  [
    {
      name = "a 1000 ms timeout at 1x takes 1000 ms of wall time";
      input = { speed = 1.; timeout_ms = 1000 };
      expect = { wall_ms = 1000. };
    };
    {
      name = "a 1000 ms timeout at 4x takes 250 ms of wall time";
      input = { speed = 4.; timeout_ms = 1000 };
      expect = { wall_ms = 250. };
    };
    {
      name = "a 1000 ms timeout at 0.5x waits 2000 ms of wall time";
      input = { speed = 0.5; timeout_ms = 1000 };
      expect = { wall_ms = 2000. };
    };
  ]

(* A daemon that answers [hello] and then sends frame after frame, one game
   frame apart; the wall clock moves [1 / speed] as far. *)
let fake_daemon speed =
  let queue = Queue.create () and n = ref 0 and wall = ref 0. in
  let send = function
    | Wire.Request { id; call = Wire.Hello _ } ->
        Queue.push
          (Session.Message
             (Wire.Response
                { id; outcome = Ok (Yojson.Safe.from_string hello_result) }))
          queue
    | _ -> ()
  in
  let recv () =
    match Queue.take_opt queue with
    | Some ev -> ev
    | None ->
        incr n;
        let t_ms = float_of_int !n *. frame_ms in
        wall := t_ms /. speed;
        Session.Message
          (Wire.Notification
             (Wire.Frame { load = 0; frame = { seq = !n; t_ms; probes = [] } }))
  in
  ({ Session.send; recv; wall_ms = (fun () -> !wall) }, wall)

let run_case c =
  let transport, wall = fake_daemon c.input.speed in
  let timed_out, game_ms =
    Session.run transport (fun () ->
        ignore (Effects.await ~timeout_ms:1 (fun _ -> true) : Effects.awaited);
        let start = Effects.now () in
        let awaited =
          Effects.await ~timeout_ms:c.input.timeout_ms (fun _ -> false)
        in
        (awaited = Effects.Timeout, Effects.now () -. start))
  in
  let timeout = float_of_int c.input.timeout_ms in
  (* The first frame past the deadline ends it. *)
  let ok =
    timed_out && game_ms > timeout
    && game_ms <= timeout +. frame_ms
    && Float.abs (!wall -. c.expect.wall_ms) <= 2. *. frame_ms /. c.input.speed
  in
  if ok then Printf.printf "ok %s\n" c.name
  else
    failwith
      (Printf.sprintf "FAILED %s: timed out %b after %.1f game ms, %.1f wall ms"
         c.name timed_out game_ms !wall)

let () = List.iter run_case cases
