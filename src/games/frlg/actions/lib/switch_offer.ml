module Text = Frlg_text

let text = "POKéMON?"
let line = Text.Text_lines.battle_message 1

let shows m =
  match Text.Line_reading.pick line [ text ] m with
  | Read _ -> true
  | No_match _ -> false

let probes () =
  Text.Line_reading.probes ~ink:Text.Line_reading.light_ink
    (Text_data.glyphs ()) line [ text ]

(* A fresh subscription is read on the next frame: well within this. *)
let look_timeout_ms = 1000

let read () =
  Effects.with_probes (probes ()) (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms (fun _ -> true) with
      | Holds m -> shows m
      | Timeout -> false)
