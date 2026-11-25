(* Talk, Fly and a checkpoint through the story runner on FireRed's Game.t,
   against a scripted screen read through the FRLG readers from recorded
   mGBA frames (Scripted_screen). *)

open Frlg_actions
open Frlg_overworld_fixtures
module S = Scripted_screen

let outcome = function
  | Ok () -> "ok"
  | Error cause -> "failed " ^ Checkpoints_run.Failure.cause_to_string cause

let run ?react f =
  let screen = S.create ?react () in
  let result = S.run screen f in
  (screen, result)

(* A presses: [dialog_ms] of text, then the overworld; [then_] after it. *)
let talk_screen ?(then_ = S.Overworld) ~dialog_ms screen (p : S.press) =
  if p.buttons = [ Wire.A ] then (
    S.show screen ~at_ms:(p.at_ms + 200) S.Dialog;
    S.show screen ~at_ms:(p.at_ms + 200 + dialog_ms) then_)

let talk ?then_ () =
  let screen, result =
    run ~react:(talk_screen ?then_ ~dialog_ms:2000) (Talk.talk ~log:ignore)
  in
  Printf.sprintf "%s after %d ms; %s" (outcome result) screen.S.clock_ms
    (S.presses_text screen)

(* Start opens the menu on row [row]; A on POKEMON the party; A on a slot its
   menu; A on FLY the fly map (no reader: the overworld's frame); the last A,
   on the fly map, the warp's black, then [lands] (the town, or the departure
   town again when the fly map closed and nothing happened). *)
let fly_screen ~row ~fade ~lands ~black_ms screen (p : S.press) =
  match p.buttons with
  | [ Wire.Start ] -> S.show screen ~at_ms:(p.at_ms + 100) (S.Start_menu row)
  | [ Wire.Up; Wire.Left ] -> S.show screen ~at_ms:p.at_ms S.Overworld
  | [ Wire.A ] -> (
      match S.screen_at screen p.at_ms with
      | S.Start_menu _ -> S.show screen ~at_ms:(p.at_ms + 300) (S.Party 1)
      | S.Party _ -> S.show screen ~at_ms:(p.at_ms + 200) (S.Member_menu 0)
      | S.Member_menu _ -> S.show screen ~at_ms:(p.at_ms + 300) S.Overworld
      | S.Overworld when fade ->
          S.show screen ~at_ms:(p.at_ms + 500) S.Black;
          S.show screen ~at_ms:(p.at_ms + 500 + black_ms) lands
      | _ -> ())
  | _ -> ()

let fly ?(row = 1) ?(fade = true) ?(lands = S.Town) ?(black_ms = 2500) () =
  let plan =
    {
      Fly.town =
        Option.get
          (Fly_towns.find (Result.get_ok (Fly_towns.load ())) "PewterCity");
      slot = 3;
      menu_row = 2;
    }
  in
  let screen, result =
    run ~react:(fly_screen ~row ~fade ~lands ~black_ms) (fun () ->
        Fly.fly ~log:ignore plan)
  in
  Printf.sprintf "%s; %s" (outcome result) (S.presses_text screen)

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "actions"
    [
      case "a talk ends once the overworld is quiet after the text" talk
        "ok after 10180 ms; A, B x7";
      case "a talk ends at the trainer's battle after it" (talk ~then_:S.Battle)
        "ok after 3380 ms; A, B x2";
      case "Fly: POKEMON, slot 3, FLY, the town, the landing" (fly ~row:1)
        "ok; Start, A, down x2, A, down, A, up+left 3000, right x4, down x4, \
         A, B x7";
      case "Fly whose fade is over between two looks of a settle"
        (fly ~black_ms:300)
        "ok; Start, A, down x2, A, down, A, up+left 3000, right x4, down x4, \
         A, B x6";
      case "Fly from a Start menu on its top row" (fly ~row:0)
        "ok; Start, down, A, down x2, A, down, A, up+left 3000, right x4, down \
         x4, A, B x7";
      case "Fly whose map closes onto the departure town fails"
        (fly ~lands:S.Overworld)
        "failed fly_no_landing: PewterCity: the screen still shows the \
         departure town; Start, A, down x2, A, down, A, up+left 3000, right \
         x4, down x4, A, B x27";
      case "Fly with no fade after the town's A fails" (fly ~fade:false)
        "failed fly_no_takeoff: PewterCity: no fade after the town's A; Start, \
         A, down x2, A, down, A, up+left 3000, right x4, down x4, A";
    ]
