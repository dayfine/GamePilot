let read_candidates (graph : 'a Graph.t) (m : Effects.measurements) =
  match graph.read m with [] -> None | cs -> Some cs

let make ~log (graph : 'a Graph.t) : 'a Screen_walk.game_steps =
  {
    read_screen =
      (fun ~hold_ms ~within_ms ->
        let watch =
          Held_screen.held (float_of_int hold_ms) (read_candidates graph)
        in
        Option.value ~default:[]
          (Held_screen.wait_for ~timeout_ms:within_ms watch));
    describe_last =
      (fun () ->
        Option.fold ~none:"no frame" ~some:graph.describe (Effects.read ()));
    send = (fun cmds -> ignore (Effects.submit cmds));
    log;
  }

let with_graph ~log (graph : 'a Graph.t) f =
  Effects.with_probes graph.probes (fun () -> f (make ~log graph))
