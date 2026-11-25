(* The move symbols reader on our synthetic frames (draw_synthetic_frames.py:
   the symbols' Packages images halved in the four moves' boxes; no console
   capture shows them yet), console frames reading as no symbols, and every
   frame shifted reading as unshifted. *)

open Plza_readers

let read m =
  String.concat ", "
    (List.map
       (function Some s -> Move_symbols.symbol_name s | None -> "-")
       (Move_symbols.read m))

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let none = "-, -, -, -"

let cases =
  [
    case "synthetic/moves-normal-super-notvery-none"
      "Effective, Super Effective, Not Very Effective, No Effect";
    case "synthetic/moves-super-none-normal-notvery"
      "Super Effective, No Effect, Effective, Not Very Effective";
    case "synthetic/moves-two-blank" "Effective, -, -, Effective";
    case "synthetic/moves-no-symbols" none;
    case "battle-hud/it-0302b-battle-no-lock-on" none;
    case "battle-hud/es-0302b-tepig-battle-start" none;
    case "arrival-to-ad/0040-text-box-advance-arrow" none;
    case "interact-prompt/arrival-to-ad-0005-prompt" none;
  ]

let () =
  Table_test.run "move_symbols" (cases @ Fixture_frames.shifted_cases read)
