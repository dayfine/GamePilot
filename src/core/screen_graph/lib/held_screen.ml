let held hold_ms read =
  let since = ref None in
  fun (m : Effects.measurements) ->
    match (read m, !since) with
    | None, _ ->
        since := None;
        None
    | Some v, Some (v', t) when v = v' ->
        if m.t_ms -. t >= hold_ms then Some v else None
    | Some v, _ ->
        since := Some (v, m.t_ms);
        if hold_ms <= 0. then Some v else None

let wait_for ~timeout_ms watch =
  let found = ref None in
  match
    Effects.await ~timeout_ms (fun m ->
        found := watch m;
        Option.is_some !found)
  with
  | Holds _ -> !found
  | Timeout -> None
