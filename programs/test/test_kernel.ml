let () =
  let t =
    Effect.Deep.match_with Kernel.now ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | Kernel.Now ->
                Some
                  (fun (k : (a, _) Effect.Deep.continuation) ->
                    Effect.Deep.continue k 42.)
            | _ -> None);
      }
  in
  assert (t = 42.);
  print_endline "kernel: virtual clock ok"
