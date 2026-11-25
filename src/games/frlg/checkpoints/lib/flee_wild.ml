module M = Frlg_actions.Menu_input

(* The battle is over once no battle screen shows; the flee is done once the
   overworld is quiet and takes input again, read by the talk settle. *)
let flee_body ~log () =
  match Frlg_battle.Wild_flee.run (Frlg_battle.Screen_driver.make ()) ~log with
  | Fled _ as fled ->
      log ("Wild battle: " ^ Frlg_battle.Wild_flee.describe fled ^ ".");
      M.settle_back ~label:"flee" ~log
  | Not_fled why -> M.fail "not_fled" why

let flee ~log () =
  match
    Effects.with_probes Frlg_battle.Battle_look.probes (fun () ->
        M.run (flee_body ~log))
  with
  | Ok () -> ()
  | Error c -> failwith ("flee: " ^ Checkpoints.Failure.cause_to_string c)
