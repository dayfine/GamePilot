(* The battle HUD's flicker filter (Plza_story.Flicker_filter.battle_hud), as
   a scene ending at a battle reads it: on with two reads within 2 s, off
   after 3 s unseen. Reads are [(seen, at_ms)], recorded in order; the case
   asks whether a last read turns it on. *)

module F = Plza_story.Flicker_filter

let case name input expectation = { Table_test.name; input; expectation }

(* Whether the filter is on with [last] after [reads]. *)
let on_after reads (seen, at_ms) () =
  let t = F.battle_hud () in
  List.iter (fun (seen, at_ms) -> F.record t seen at_ms) reads;
  string_of_bool (F.on_with t seen at_ms)

let cases =
  [
    case "one read of the HUD: off" (on_after [] (true, 0.0)) "false";
    case "one read of the HUD, then none: off"
      (on_after [ (true, 0.0) ] (false, 250.0))
      "false";
    case "two reads of the HUD 250 ms apart: on"
      (on_after [ (true, 0.0) ] (true, 250.0))
      "true";
    case "two reads of the HUD 2 s apart: on"
      (on_after [ (true, 0.0) ] (true, 2000.0))
      "true";
    case "two reads of the HUD 2.5 s apart: off"
      (on_after [ (true, 0.0) ] (true, 2500.0))
      "false";
    case "on, then unseen 2.75 s: still on"
      (on_after [ (true, 0.0); (true, 250.0) ] (false, 3000.0))
      "true";
    case "on, then unseen 3 s: off"
      (on_after [ (true, 0.0); (true, 250.0) ] (false, 3250.0))
      "false";
  ]

let () = Table_test.run "plza flicker filter" cases
