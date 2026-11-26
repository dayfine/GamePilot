type 'screen game_steps = {
  read_screen : hold_ms:int -> within_ms:int -> 'screen list;
  describe_last : unit -> string;
  send : Wire.command list -> unit;
  log : string -> unit;
}

type 'screen failure =
  | Unread of { last : string }
  | No_path of { from : 'screen }
  | Out_of_hops of { on : 'screen }
  | Not_on of { wanted : 'screen; last : string }

let default_max_hops = 40
let default_hold_ms = 1000
let default_within_ms = 3000
let max_unread_presses = 3

let failure_to_string (graph : 'a Graph.t) = function
  | Unread { last } -> Printf.sprintf "%s: screen unread (%s)" graph.name last
  | No_path { from } ->
      Printf.sprintf "%s: no path from %s" graph.name (graph.show from)
  | Out_of_hops { on } ->
      Printf.sprintf "%s: out of hops on %s" graph.name (graph.show on)
  | Not_on { wanted; last } ->
      Printf.sprintf "%s: expected %s before acting (%s)" graph.name
        (graph.show wanted) last

let settle ~expected = function
  | [] -> None
  | [ single ] -> Some single
  | candidates -> (
      match expected with
      | Some target when List.mem target candidates -> Some target
      | _ -> None)

let arrive_hold_ms = function Graph.Held ms -> ms | First_read -> 0

let step_from ~max_hops graph steps ~at ~hops current =
  if at current then Ok (`Done current)
  else if hops >= max_hops then Error (Out_of_hops { on = current })
  else
    match Graph.path graph ~from:current ~at with
    | None -> Error (No_path { from = current })
    | Some [] -> Ok (`Done current)
    | Some (edge :: _) ->
        steps.send edge.input;
        Ok (`Next (edge.leads_to, arrive_hold_ms edge.arrive, edge.within_ms))

let send_unread_press (graph : 'a Graph.t) steps ~unread_presses cmds =
  let msg =
    Printf.sprintf "%s: screen unread (%s); sending recovery press %d/%d"
      graph.name (steps.describe_last ()) (unread_presses + 1)
      max_unread_presses
  in
  steps.log msg;
  steps.send cmds;
  Ok ()

let handle_unread (graph : 'a Graph.t) steps ~unread_presses =
  match graph.when_unread with
  | Fail -> Error (Unread { last = steps.describe_last () })
  | Press _ when unread_presses >= max_unread_presses ->
      Error (Unread { last = steps.describe_last () })
  | Press cmds -> send_unread_press graph steps ~unread_presses cmds

type 'screen walk_state = {
  hops : int;
  unread_presses : int;
  expected : 'screen option;
  wait_hold : int;
  wait_within : int;
}

let on_unread_step ~hold_ms ~within_ms graph steps st =
  let next =
    {
      st with
      unread_presses = st.unread_presses + 1;
      expected = None;
      wait_hold = hold_ms;
      wait_within = within_ms;
    }
  in
  Result.map
    (fun () -> `Continue next)
    (handle_unread graph steps ~unread_presses:st.unread_presses)

let next_state hops target wait_hold wait_within =
  {
    hops = hops + 1;
    unread_presses = 0;
    expected = Some target;
    wait_hold;
    wait_within;
  }

let advance_hop hops = function
  | `Done s -> `Done s
  | `Next (target, wait_hold, wait_within) ->
      `Continue (next_state hops target wait_hold wait_within)

let walk_step ~max_hops ~hold_ms ~within_ms graph steps ~at st =
  let candidates =
    steps.read_screen ~hold_ms:st.wait_hold ~within_ms:st.wait_within
  in
  match settle ~expected:st.expected candidates with
  | None -> on_unread_step ~hold_ms ~within_ms graph steps st
  | Some current ->
      Result.map (advance_hop st.hops)
        (step_from ~max_hops graph steps ~at ~hops:st.hops current)

let go_to ?(max_hops = default_max_hops) ?(hold_ms = default_hold_ms)
    ?(within_ms = default_within_ms) graph steps ~at =
  let rec loop st =
    match walk_step ~max_hops ~hold_ms ~within_ms graph steps ~at st with
    | Error e -> Error e
    | Ok (`Done s) -> Ok s
    | Ok (`Continue next) -> loop next
  in
  loop
    {
      hops = 0;
      unread_presses = 0;
      expected = None;
      wait_hold = hold_ms;
      wait_within = within_ms;
    }

let wait_after_act steps (edge : 'a Graph.edge) =
  let candidates =
    steps.read_screen
      ~hold_ms:(arrive_hold_ms edge.arrive)
      ~within_ms:edge.within_ms
  in
  match settle ~expected:(Some edge.leads_to) candidates with
  | Some s -> Ok s
  | None -> Error (Unread { last = steps.describe_last () })

let take ?(hold_ms = default_hold_ms) ?(within_ms = default_within_ms) graph
    steps ~from act_name =
  match Graph.find_act graph ~from act_name with
  | None -> Error (No_path { from })
  | Some edge -> (
      let candidates = steps.read_screen ~hold_ms ~within_ms in
      match settle ~expected:None candidates with
      | Some s when s = from ->
          steps.send edge.input;
          wait_after_act steps edge
      | _ -> Error (Not_on { wanted = from; last = steps.describe_last () }))
