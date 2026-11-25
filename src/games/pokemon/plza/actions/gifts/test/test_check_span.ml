(* Claim_gifts.check: a run's start and stop are points of its own steps. The
   code alone skips the Internet gift's screens (mystery-gift, gift-list,
   card), the Internet gift alone the code's (keyboard, code-card,
   disconnect), and --slot-2-to-1 every gift's; any of them can start on a
   later point of its own, so a run that stopped can be finished with the
   same flag. *)

module C = Plza_gifts.Claim_gifts

let check ?(from = "overworld") ?stop_at mode () =
  match C.check { from; stop_at; mode } with
  | Ok () -> "ok"
  | Error e -> "error: " ^ e

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "check_span"
    [
      case "both gifts, the whole run" (check Both_gifts) "ok";
      case "both gifts, from the Boxes" (check ~from:"boxes" Both_gifts) "ok";
      case "the code alone, from the keyboard"
        (check ~from:"keyboard" Code_gift_only)
        "ok";
      case "the code alone, from the Boxes"
        (check ~from:"boxes" Code_gift_only)
        "ok";
      case "the code alone, from the Internet gift's card: refused"
        (check ~from:"card" Code_gift_only)
        "error: no point card in this run (overworld, code, keyboard, \
         code-card, disconnect, after-gifts, boxes, moved, save, saved)";
      case "the Internet gift alone, stopped on the Mystery Gift menu"
        (check ~stop_at:"code" Internet_gift_only)
        "ok";
      case "the Internet gift alone, stopped on the keyboard: refused"
        (check ~stop_at:"keyboard" Internet_gift_only)
        "error: no point keyboard in this run (overworld, mystery-gift, \
         gift-list, card, code, after-gifts, boxes, moved, save, saved)";
      case "slot 2 to slot 1, kept open on the overworld"
        (check ~stop_at:"saved" Box_slot_2_to_1)
        "ok";
      case "slot 2 to slot 1, from after the gifts: refused"
        (check ~from:"after-gifts" Box_slot_2_to_1)
        "error: no point after-gifts in this run (overworld, boxes, moved, \
         save, saved)";
      case "a stop before the start: refused"
        (check ~from:"boxes" ~stop_at:"code" Both_gifts)
        "error: the stop code is not after the start boxes";
    ]
