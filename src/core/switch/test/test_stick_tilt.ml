(* Stick_tilt: angles to stick values, and a tilt walked or run. *)

let case name input expectation = { Table_test.name; input; expectation }

(* A tilt to two places; a rounded -0.00 is 0.00. *)
let two v = if Float.abs v < 0.005 then "0.00" else Printf.sprintf "%.2f" v

let xy (s : Wire.stick) =
  let x, y = (s :> float * float) in
  Printf.sprintf "(%s, %s)" (two x) (two y)

let toward degrees () =
  match Switch.Stick_tilt.toward ~degrees with Ok s -> xy s | Error e -> e

let tilt ?run duration_ms () =
  match
    Switch.Stick_tilt.tilt ?run ~degrees:90.0 ~duration_ms ~release_ms:100 ()
  with
  | Ok (Press { buttons; left_stick = Some s; hold_ms; cooldown_ms; _ }) ->
      Printf.sprintf "%s%s %d/%d"
        (String.concat ""
           (List.map (fun b -> Wire.string_of_button b ^ "+") buttons))
        (xy s) hold_ms cooldown_ms
  | Ok _ -> "not a stick press"
  | Error e -> e

let run = { Switch.Stick_tilt.button = Wire.B; speedup = 2.0 }

let () =
  Table_test.run "stick_tilt"
    [
      case "0 degrees: straight on, up" (toward 0.0) "(0.00, 1.00)";
      case "90 degrees: right" (toward 90.0) "(1.00, 0.00)";
      case "-90 degrees: left" (toward (-90.0)) "(-1.00, 0.00)";
      case "180 degrees: back, down" (toward 180.0) "(0.00, -1.00)";
      case "-66 degrees: (sin, cos)" (toward (-66.0)) "(-0.91, 0.41)";
      case "a walk: the stick alone, for its time" (tilt 1000)
        "(1.00, 0.00) 1000/100";
      case "a run: its button with the stick, for its time over the speedup"
        (tilt ~run 1001) "B+(1.00, 0.00) 500/100";
    ]
