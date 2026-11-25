open Engine_run

module type SAVED = sig
  type t

  val to_yojson : t -> Yojson.Safe.t
  val of_yojson : Yojson.Safe.t -> (t, string) result
end

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

let missing ~checkpoint ~label ~path =
  Printf.sprintf
    "no state for %s %s yet (%s): a run of %s on mGBA that reaches %s keeps \
     one, e.g. run/run_checkpoints_on_mgba.sh ... --from %s --to %s --mode \
     testing"
    checkpoint label path checkpoint label checkpoint checkpoint

type tracker = { mutable next : int; mutable clean : bool }

let tracker ~first = { next = first; clean = true }

let hear t index (progress : _ Event_progress.t) =
  match progress with
  | Started -> t.clean && index = t.next
  | Passed | Skipped _ ->
      if index = t.next then t.next <- index + 1 else t.clean <- false;
      false
  | Failed _ ->
      t.clean <- false;
      false

module Make (S : SAVED) = struct
  let write_kept state kept =
    Out_channel.with_open_bin (kept_path state) (fun out ->
        Out_channel.output_string out
          (Yojson.Safe.to_string (S.to_yojson kept) ^ "\n"))

  let read_kept ~missing state =
    let file = kept_path state in
    if not (Sys.file_exists file) then Error missing
    else Result.bind (Repo_io.Json_file.read file) S.of_yojson
end
