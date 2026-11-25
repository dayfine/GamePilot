let unread walk h =
  Engine_run.Failure.cause ~repeats:true "heading_unread"
    (Printf.sprintf
       "%s: its heading (%.0f deg) needs the minimap arrow, which no reader \
        here reads"
       walk h)

let check walk = function None -> Ok () | Some h -> Error (unread walk h)
