module Make (T : Engine_terms.GAME_TERMS) = struct
  let dir ~states ~checkpoint = Filename.concat states (checkpoint ^ ".events")
  let file ~index ~event_id = Printf.sprintf "%02d-%s.ss" (index + 1) event_id

  let path ~states ~checkpoint ~index ~event_id =
    Filename.concat (dir ~states ~checkpoint) (file ~index ~event_id)

  let kept_path state = Filename.remove_extension state ^ ".json"

  let is_other_state ~index ~keep name =
    let prefix = Printf.sprintf "%02d-" (index + 1) in
    String.starts_with ~prefix name
    && name <> keep
    && name <> Filename.basename (kept_path keep)
    && (Filename.check_suffix name ".ss" || Filename.check_suffix name ".json")

  type kept = { start : T.start_reads; at : T.observed option }

  let option_json f = function Some v -> f v | None -> `Null

  let kept_to_json { start; at } =
    `Assoc
      (T.start_reads_to_json start
      @ [ ("at", option_json T.observed_to_json at) ])

  let ( let* ) = Result.bind

  let at_of_json = function
    | `Null -> Ok None
    | json ->
        Result.map_error (fun e -> "at: " ^ e) (T.observed_of_json json)
        |> Result.map Option.some

  let kept_of_json = function
    | `Assoc fields ->
        let* start = T.start_reads_of_json fields in
        let* at =
          at_of_json (Option.value (List.assoc_opt "at" fields) ~default:`Null)
        in
        Ok { start; at }
    | _ -> Error "what is kept is not an object"

  let missing ~checkpoint ~label ~path =
    Printf.sprintf
      "no state for %s %s yet (%s): a run of %s on mGBA that reaches %s keeps \
       one, e.g. run/run_checkpoints_on_mgba.sh ... --from %s --to %s --mode \
       testing"
      checkpoint label path checkpoint label checkpoint checkpoint

  type tracker = { mutable next : int; mutable clean : bool }

  let tracker ~first = { next = first; clean = true }

  let hear t index (progress : Event_progress.t) =
    match progress with
    | Started -> t.clean && index = t.next
    | Passed | Skipped _ ->
        if index = t.next then t.next <- index + 1 else t.clean <- false;
        false
    | Failed _ ->
        t.clean <- false;
        false
end
