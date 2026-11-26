(* Effects: virtual clock (Effects.now) and frame saving (Effects.save_run_frame)
   tested with an in-memory OCaml effect handler that fakes the daemon clock and
   records (or refuses) frame-save requests. *)

let () =
  let t =
    Effect.Deep.match_with Effects.now ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Effects.Now ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    Effect.Deep.continue k 42.)
            | _ -> None);
      }
  in
  assert (t = 42.);
  print_endline "effects: virtual clock ok"

(* save_run_frame: the frames a run keeps go into its folder; none without
   one; a daemon that refuses the save does not fail the step. *)
let saved_frames ?(refuse = false) f =
  let saved = ref [] in
  Effect.Deep.match_with f ()
    {
      retc = (fun () -> List.rev !saved);
      exnc = raise;
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Effects.Save_frame path ->
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  if refuse then
                    Effect.Deep.discontinue k
                      (Effects.Rpc_error
                         { code = -1; message = "no"; data = None })
                  else (
                    saved := path :: !saved;
                    Effect.Deep.continue k 1))
          | _ -> None);
    }

let () =
  let keep () = Effects.save_run_frame "proof-a.png" in
  assert (
    saved_frames (fun () -> Effects.with_run_folder "run" keep)
    = [ Filename.concat "run" "proof-a.png" ]);
  assert (saved_frames keep = []);
  assert (
    saved_frames ~refuse:true (fun () -> Effects.with_run_folder "run" keep)
    = []);
  print_endline "effects: run frames ok"
