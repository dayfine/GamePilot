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

(* The latest frame may predate the subscription and carry no result for the
   line: wait for one that does, as [Line_reading.read] waits for its probes. *)
let has_line m = Effects.probe m (Text.Line_reading.probe_id line text) <> None

let read () =
  Effects.with_probes (probes ()) (fun () ->
      match Effects.await ~timeout_ms:look_timeout_ms has_line with
      | Holds m -> shows m
      | Timeout -> false)
