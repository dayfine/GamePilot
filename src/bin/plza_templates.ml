(* The PLZA readers' find templates (Plza_readers.Blob_assets), read from the
   repo and uploaded to the daemon, for gamepilot checkpoints --program
   plza.autostory (Plza_series). *)

module Assets = Plza_readers.Blob_assets

let ( let* ) = Result.bind

let read_file path =
  if Sys.file_exists path then
    Ok (In_channel.with_open_bin path In_channel.input_all)
  else Error (path ^ ": no such template")

let upload_one dir name =
  Result.map Effects.upload_template (read_file (Filename.concat dir name))

let upload_from dir =
  let up = upload_one dir and f = Assets.file_names in
  let* dialog_white_arrow = up f.dialog_white_arrow in
  let* dialog_black_arrow = up f.dialog_black_arrow in
  let* dialog_teal_arrow = up f.dialog_teal_arrow in
  let* choice_arrow = up f.choice_arrow in
  let* advance_chevron_shape = up f.advance_chevron_shape in
  let* button_a = up f.button_a in
  let* button_dpad_up = up f.button_dpad_up in
  let* button_dpad_down = up f.button_dpad_down in
  let* button_dpad_up_interior = up f.button_dpad_up_interior in
  let* button_dpad_down_interior = up f.button_dpad_down_interior in
  let* move_no_effect = up f.move_no_effect in
  let* move_not_very_effective = up f.move_not_very_effective in
  let* move_effective = up f.move_effective in
  let* move_super_effective = up f.move_super_effective in
  Ok
    {
      Assets.dialog_white_arrow;
      dialog_black_arrow;
      dialog_teal_arrow;
      choice_arrow;
      advance_chevron_shape;
      button_a;
      button_dpad_up;
      button_dpad_down;
      button_dpad_up_interior;
      button_dpad_down_interior;
      move_no_effect;
      move_not_very_effective;
      move_effective;
      move_super_effective;
    }

(* Each template, uploaded to the daemon: its hash. *)
let upload () =
  match Program_registry.locate Assets.folder with
  | None -> Error (Assets.folder ^ " not found from here: run in the repo")
  | Some dir -> upload_from dir
