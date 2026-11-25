(* After a won battle, the text before the overworld comes back: the battle
   steps' rule (Event_rule) on a real frame of it and on a scripted flow.
   mg-05 testing 1 (mGBA): Lea & Jed's defeat line ("LEA: Ohh! But JED looks
   cool even in a loss!") showed with no arrow and with the HP boxes where a
   single battle's are not; it read as an evolution, which never gets a press,
   and the battle timed out after 60 s. *)

open Frlg_battle

let case name input expectation = { Table_test.name; input; expectation }

let defeat_line =
  lazy
    (let images = Wire.read_image_probes "battle.mgba.probes.jsonl" in
     let probes =
       List.assoc "mail-glitch-route16/lea-jed-defeat-text__ally.png" images
     in
     let m : Effects.measurements = { seq = 0; t_ms = 0.; probes } in
     Battle_look.of_measurements m)

let screen facts = Battle_look.(screen_name (classify facts))

let step_name : Event_rule.step -> string = function
  | Report e -> Battle.event_name e
  | Press b -> "press " ^ Wire.string_of_button b
  | Look -> "look"

(* Each look's facts at its time; the rule's answers in order. *)
let flow looks () =
  let _, names =
    List.fold_left
      (fun (state, names) (facts, at_ms) ->
        let state, step = Event_rule.next state facts ~at_ms in
        (state, step_name step :: names))
      (Event_rule.start ~at_ms:0., [])
      looks
  in
  String.concat ", " (List.rev names)

let f = Battle_look.nothing

(* The trainers' lines once their battlers are gone: the text box alone. *)
let trainer_text = { f with text_box = true; evolution = true }

let cases =
  [
    case "the defeat line's frame is battle text, not an evolution"
      (fun () -> screen (Lazy.force defeat_line))
      "battle text";
    case
      "won, the defeat line held 6 s gets B, the trainers' line too, then the \
       overworld"
      (flow
         [
           (Lazy.force defeat_line, 500.);
           (Lazy.force defeat_line, 6500.);
           (trainer_text, 7000.);
           (trainer_text, 12600.);
           (f, 13000.);
           (f, 16100.);
         ])
      "look, press B, look, press B, look, battle over";
  ]

let () = Table_test.run "battle end text" cases
