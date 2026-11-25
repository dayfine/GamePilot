(* gamepilot ctl [--port N] [--owner LABEL] delete-save GAME | delete-save --confirm

   Deletes one game's save data on the Switch from System Settings, in two
   steps (Switch_home.Delete_save, the lab's delete-save route): [delete-save
   GAME] closes the running game and stops on the Caution screen with the red
   Delete Save Data button selected, deleting nothing; after a look at the
   screen, [delete-save --confirm] presses it, OK on the success popup, and
   HOME. Through a running daemon under the input lease, like [ctl park]
   (Console_park_command); the daemon must show the whole frame (--viewport
   native).

   GAME is a key of [icons]: the game's icon on its "Delete Save Data for
   <user>" page, 82x82 frame pixels (the 90 px icon at (90, 30), 4 px in).
   plza's is cut from console B's capture of that page
   (core/switch_home/test/images/delete-save/za-page-delete-save-data-for-user.png).
   No FireRed page was captured: firered's is the list's 135 px icon
   (game-list-za-first.png, at (157, 397)) scaled to 90 px (Lanczos), then cut
   the same way; Z-A's made so scores 0.0054 on its page against the reader's
   0.02. *)

let icons =
  [
    ("plza", "src/games/plza/assets/delete-save-icon.png");
    ("firered", "src/games/frlg/assets/delete-save-icon-firered.png");
  ]

let keys = String.concat ", " (List.map fst icons)

let usage_line =
  "      | delete-save GAME | delete-save --confirm  (the Switch: close the\n\
  \        game and stop on its red Delete Save Data button; then press it.\n\
  \        GAME: " ^ keys ^ ")\n"

let read_icon key =
  match List.assoc_opt key icons with
  | None -> Error (Printf.sprintf "delete-save: no icon for %s (%s)" key keys)
  | Some path -> (
      match Repo_io.Repo_files.locate path with
      | None -> Error ("delete-save: " ^ path ^ " not found above here")
      | Some file -> Ok (In_channel.with_open_bin file In_channel.input_all))

let to_caution ~port ~owner key =
  Result.map
    (fun icon_png ->
      Console_park_command.on_port ~port ~owner
        (`Delete_save { Switch_home.Delete_save.key; icon_png }))
    (read_icon key)

let main ~port ~owner = function
  | [ "--confirm" ] ->
      Ok (Console_park_command.on_port ~port ~owner `Delete_save_confirm)
  | [ key ] -> to_caution ~port ~owner key
  | _ -> Error ("ctl: delete-save takes GAME or --confirm (GAME: " ^ keys ^ ")")
