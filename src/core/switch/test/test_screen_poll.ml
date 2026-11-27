(* Screen_poll over scripted screen reads: (time, HOME, holds), the last repeated,
   and the waits between them. *)

let case name input expectation = { Table_test.name; input; expectation }

let poll screens () =
  let reads = ref screens and said = ref [] in
  let read_screen () =
    match !reads with
    | [ last ] -> last
    | l :: rest ->
        reads := rest;
        l
    | [] -> (0.0, false, false)
  in
  let steps : _ Switch.Screen_poll.game_steps =
    {
      read_screen;
      wait = (fun ms -> said := Printf.sprintf "wait %d" ms :: !said);
    }
  in
  let at_ms (t, _, _) = t and home_menu (_, h, _) = h in
  let outcome =
    match
      Switch.Screen_poll.until steps ~at_ms ~home_menu ~poll_ms:250
        ~timeout_ms:1000 (fun (_, _, holds) -> holds)
    with
    | Holds (t, _, _) -> Printf.sprintf "holds at %g" t
    | Timed_out (t, _, _) -> Printf.sprintf "timed out at %g" t
    | Home_menu -> "home menu"
  in
  String.concat ", " (List.rev !said @ [ outcome ])

let () =
  Table_test.run "screen_poll"
    [
      case "holds on the third read, a wait between each"
        (poll
           [ (0.0, false, false); (250.0, false, false); (500.0, false, true) ])
        "wait 250, wait 250, holds at 500";
      case "the HOME menu is checked before the check"
        (poll [ (0.0, true, true) ])
        "home menu";
      case "timed out once the reads' clock passes the timeout"
        (poll
           [
             (0.0, false, false); (600.0, false, false); (1000.0, false, false);
           ])
        "wait 250, wait 250, timed out at 1000";
      case "a clock that stands still: timed out after timeout / poll + 1 reads"
        (poll [ (0.0, false, false) ])
        "wait 250, wait 250, wait 250, wait 250, timed out at 0";
    ]
