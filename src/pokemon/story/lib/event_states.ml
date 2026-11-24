let dir ~states ~checkpoint = Filename.concat states (checkpoint ^ ".events")
let file ~index ~event_id = Printf.sprintf "%02d-%s.ss" (index + 1) event_id

let path ~states ~checkpoint ~index ~event_id =
  Filename.concat (dir ~states ~checkpoint) (file ~index ~event_id)

let start_reads_path state = Filename.remove_extension state ^ ".start.json"

let is_other_state ~index ~keep name =
  let prefix = Printf.sprintf "%02d-" (index + 1) in
  String.starts_with ~prefix name
  && name <> keep
  && name <> Filename.basename (start_reads_path keep)
  && (Filename.check_suffix name ".ss"
     || Filename.check_suffix name ".start.json")

type start_reads = { start_money : int option }

let start_reads_to_json r =
  `Assoc
    [
      ( "start_money",
        match r.start_money with Some n -> `Int n | None -> `Null );
    ]

let start_reads_of_json = function
  | `Assoc fields -> (
      match List.assoc_opt "start_money" fields with
      | Some (`Int n) -> Ok { start_money = Some n }
      | Some `Null | None -> Ok { start_money = None }
      | Some _ -> Error "start_money is not a number")
  | _ -> Error "the start reads are not an object"

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
