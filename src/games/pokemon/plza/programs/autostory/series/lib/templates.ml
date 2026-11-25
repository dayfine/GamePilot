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
  let* button_minus = up f.button_minus in
  let* button_b = up f.button_b in
  let* button_right = up f.button_right in
  let* alert_eye = up f.alert_eye in
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
      button_minus;
      button_b;
      button_right;
      alert_eye;
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
  match Repo_io.Repo_files.locate Assets.folder with
  | None -> Error (Assets.folder ^ " not found from here: run in the repo")
  | Some dir -> upload_from dir
