(* Tests for v1.21 session primitives: gap notifications (take_gaps),
   absolute-time submit (submit_at), and in-run lease renewal (renew_lease). *)

let expect name ok =
  if ok then Printf.printf "ok %s\n" name else failwith ("FAILED " ^ name)

let hello_result =
  {|{"protocol":1,"daemon":"gamepilot-daemon/0.1","backend":{"kind":"switch","game_code":"","frame_rate":60,"width":1920,"height":1080,"viewport":{"x":0,"y":0,"w":1,"h":1},"game_size":{"width":1920,"height":1080}},"probe_kinds":["core.template_ncc@1"]}|}

let lease_result owner ttl_ms =
  Printf.sprintf
    {|{"lease":{"owner":%S,"client":"gamepilot-programs/0.1","held_ms":0,"ttl_ms":%d}}|}
    owner ttl_ms

let frame seq t_ms =
  Session.Message
    (Wire.Notification
       (Wire.Frame { load = 0; frame = { seq; t_ms; probes = [] } }))

let gap from_seq to_seq from_t_ms to_t_ms =
  Session.Message
    (Wire.Notification (Wire.Gap { from_seq; to_seq; from_t_ms; to_t_ms }))

let fake_daemon script =
  let queue = Queue.of_seq (List.to_seq script) in
  let sent = ref [] in
  let answer (call : Wire.call) =
    Yojson.Safe.from_string
      (match call with
      | Wire.Hello _ -> hello_result
      | Wire.Submit { batch_id; start_at_t_ms; _ } ->
          let t_ms = Option.value start_at_t_ms ~default:100. in
          Queue.push
            (Session.Message
               (Wire.Notification (Wire.Batch_done { batch_id; seq = 10; t_ms })))
            queue;
          Printf.sprintf {|{"batch_id":%S,"start_seq":1}|} batch_id
      | Wire.Lease_acquire { owner; ttl_ms } ->
          lease_result owner (Option.value ttl_ms ~default:60000)
      | _ -> "{}")
  in
  let send (m : Wire.message) =
    sent := m :: !sent;
    match m with
    | Wire.Request { id; call } ->
        Queue.push
          (Session.Message (Wire.Response { id; outcome = Ok (answer call) }))
          queue
    | _ -> ()
  in
  let recv () =
    match Queue.take_opt queue with
    | Some ev -> ev
    | None -> Session.Closed "done"
  in
  ({ Session.send; recv; wall_ms = (fun () -> 0.) }, sent)

let () =
  (* 1. Gap notifications accumulate in order and drain on take_gaps. *)
  let g1 =
    { Wire.from_seq = 2; to_seq = 4; from_t_ms = 16.7; to_t_ms = 83.3 }
  in
  let transport, _ =
    fake_daemon [ frame 1 16.7; gap 2 4 16.7 83.3; frame 5 83.3 ]
  in
  Session.run transport (fun () ->
      ignore
        (Effects.await ~timeout_ms:1000 (fun f -> f.seq = 5) : Effects.awaited);
      expect "take_gaps returns recorded gap" (Effects.take_gaps () = [ g1 ]);
      expect "second take_gaps is empty" (Effects.take_gaps () = []))

let () =
  (* 2. submit_at sends start_at_t_ms on the wire. *)
  let transport, sent = fake_daemon [] in
  let cmd = [ Wire.press ~hold_ms:50 ~cooldown_ms:50 [ A ] ] in
  Session.run transport (fun () ->
      let d = Effects.submit_at ~start_at_t_ms:25000.5 cmd in
      expect "submit_at returns batch_done" (d.t_ms = 25000.5));
  let saw_start_at =
    List.exists
      (function
        | Wire.Request
            { call = Wire.Submit { start_at_t_ms = Some 25000.5; _ }; _ } ->
            true
        | _ -> false)
      !sent
  in
  expect "submit_at encodes start_at_t_ms" saw_start_at

let () =
  (* 3. renew_lease sends lease.acquire with session owner and optional ttl_ms. *)
  let transport, sent = fake_daemon [] in
  Session.run ~lease:("bdsp-rng", Some 45000) transport (fun () ->
      Effects.renew_lease ();
      Effects.renew_lease ~ttl_ms:90000 ());
  let acquires =
    List.rev !sent
    |> List.filter_map (function
         | Wire.Request { call = Wire.Lease_acquire { owner; ttl_ms }; _ } ->
             Some (owner, ttl_ms)
         | _ -> None)
  in
  expect "renew_lease reuses session owner/ttl and accepts override"
    (acquires
    = [
        ("bdsp-rng", Some 45000);
        ("bdsp-rng", Some 45000);
        ("bdsp-rng", Some 90000);
      ])
