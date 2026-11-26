(* The move symbols reader on console frames of 01.03's battle with Andi
   (console B, 2026-11-25: ZL held, Tackle top and Tail Whip right, both
   Effective; and the battle without ZL), on our drawn frames (the four
   symbols' Packages images halved in the four boxes; draw_synthetic_frames.py),
   other frames reading as no symbols, and every frame shifted reading the top
   move as unshifted.

   Headroom (masked scores, bound 150): Tackle's ring scores 110 to 116 on the
   console frames and 91 to 125 shifted, the next symbol 158 or more; the
   frames without ZL score 212 or more. Tail Whip's ring scores 146 to 160, so
   it reads on some frames and not others (the fork's bound as it is); the
   battle takes the most effective move read, Tackle when both are. One known
   miss: brightness 1.1 on the first ZL frame (Fixture_frames.known_misses). *)

open Plza_readers

let name = function Some s -> Move_symbols.symbol_name s | None -> "-"
let read m = String.concat ", " (List.map name (Move_symbols.read m))
let top m = name (List.nth_opt (Move_symbols.read m) 0 |> Option.join)

let case frame expectation : Table_test.case =
  {
    name = frame;
    input = (fun () -> read (Fixture_frames.frame frame));
    expectation;
  }

let none = "-, -, -, -"

let cases =
  [
    case "move-symbols/0303-andi-zl-held-1" "Effective, -, -, -";
    case "move-symbols/0303-andi-zl-held-3" "Effective, -, -, -";
    case "move-symbols/0303-andi-zl-held-target-4" "Effective, -, Effective, -";
    case "move-symbols/0303-andi-zl-held-target-5" "Effective, -, Effective, -";
    case "move-symbols/0303-andi-battle-no-zl-1" none;
    case "move-symbols/0303-andi-battle-no-zl-3" none;
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
  Table_test.run "move_symbols"
    (cases @ Fixture_frames.shifted_cases ~misses:true top)
