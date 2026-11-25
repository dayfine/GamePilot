(* The settle after a warp on console B, whose frames show the game 160 or
   335 ms late (Scripted_screen's capture latencies): the Escape Rope out of
   Pokemon Tower (mg-04a testing run 1, 2026-11-24). USE closes the bag (a
   black fade) onto "used the ESCAPE ROPE" over the tower; B on that text
   spins the player, and the warp's fade (0.6 s of black) lands in Lavender
   Town. The settle looked once every 1.4 s and saw neither black, so it
   failed as a map mismatch with the player outside the tower. *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let latencies = [ 160; 335 ]
let a p = p.S.buttons = [ Wire.A ]
let b p = p.S.buttons = [ Wire.B ]

(* The game's times; each screen shows the press's latency later. [fades]
   false: neither the bag's close nor the warp shows a fade the probe reads
   (only the new place does). *)
let escape_rope ~fades screen (p : S.press) =
  let late = S.latency_of screen p in
  let show d s = S.show screen ~at_ms:(p.at_ms + d + late) s in
  match S.screen_at screen (p.at_ms + late) with
  | S.Item_menu when a p ->
      if fades then show 100 S.Black;
      show 500 S.Dialog
  | S.Dialog when b p ->
      show 0 S.Overworld;
      if fades then show 300 S.Black;
      show 900 S.Town
  | _ -> ()

let use_a = Wire.press ~hold_ms:160 ~cooldown_ms:0 [ Wire.A ]

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Pokemon_checkpoints.Failure.cause_to_string cause

(* The settle from the USE on, with the departure read on the overworld
   before the bag when [arrival]. The text is the outcome, what proved the
   warp, and the presses. *)
let use ~fades ~arrival () =
  let screen =
    S.create ~react:(escape_rope ~fades) ~capture_latencies_ms:latencies ()
  in
  let last_line = ref "" in
  let log line = last_line := line in
  let result =
    S.run screen (fun () ->
        Effects.with_probes Frlg_readers.Scene_signature.probes (fun () ->
            let before =
              Frlg_readers.Scene_signature.read (Option.get (Effects.read ()))
            in
            S.show screen ~at_ms:(screen.S.clock_ms + 1) S.Item_menu;
            ignore (Effects.submit [ Wire.Wait { wait_ms = 100 } ]);
            let arrived =
              if arrival then
                Option.map
                  (fun before -> Frlg_readers.Scene_signature.left ~before)
                  before
              else None
            in
            Scene_looks.settle After_warp ?arrived ~start:[ use_a ]
              ~label:"use escape-rope" ~battle_ends:false ~log))
  in
  Printf.sprintf "%s; %s; %s" (outcome result) !last_line
    (S.presses_text screen)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "warp settle"
    [
      case
        "a warp whose fade is over between two looks still settles (mg-04a \
         testing run 1)"
        (use ~fades:true ~arrival:false)
        "ok; [Settle] use escape-rope: over; black fade back up.; A, B x7";
      case "a warp with no fade the probe reads settles on the arrival read"
        (use ~fades:false ~arrival:true)
        "ok; [Settle] use escape-rope: over; arrival read.; A, B x7";
      case "no fade and no arrival read is still a map mismatch"
        (use ~fades:false ~arrival:false)
        "failed not_settled: use escape-rope: no fade or banner within 120 s, \
         so we are not where the step goes (map mismatch).; [Settle] use \
         escape-rope: no fade or banner within 120 s, so we are not where the \
         step goes (map mismatch).; A, B x89";
    ]
