(* How [gamepilot ctl] reads a script line or a command: one case per form of
   each command, labB.sh's lines included, and the errors a typo gets. *)

let show = function
  | Ok None -> "skip"
  | Ok (Some (Ctl_script.Press { button; hold_ms; wait_ms; times })) ->
      Printf.sprintf "press %s hold %d wait %d x%d"
        (Wire.string_of_button button)
        hold_ms wait_ms times
  | Ok (Some (Wait ms)) -> Printf.sprintf "wait %d" ms
  | Ok (Some (Shot file)) -> "shot " ^ file
  | Ok (Some (Read reader)) -> "read " ^ reader
  | Ok (Some Status) -> "status"
  | Error e -> "error: " ^ e

let line name text expectation =
  {
    Table_test.name;
    input = (fun () -> show (Ctl_script.parse_line text));
    expectation;
  }

let () =
  Table_test.run "ctl_script"
    [
      line "labB press: button, hold, wait" "press A 100 800"
        "press A hold 100 wait 800 x1";
      line "labB dpad: direction, hold, wait" "dpad DOWN 160 800"
        "press Down hold 160 wait 800 x1";
      line "press with the defaults" "press B" "press B hold 100 wait 500 x1";
      line "press with a hold only" "press A 50" "press A hold 50 wait 500 x1";
      line "press with flags" "press A --hold 120 --wait 900"
        "press A hold 120 wait 900 x1";
      line "dpad with a count" "dpad UP 3" "press Up hold 100 wait 500 x3";
      line "dpad with a count and flags" "dpad left 2 --wait 300"
        "press Left hold 100 wait 300 x2";
      line "buttons in any case: the Switch's Plus" "press plus"
        "press Plus hold 100 wait 500 x1";
      line "the Switch's Minus" "press MINUS 80 200"
        "press Minus hold 80 wait 200 x1";
      line "GBA Start" "press start" "press Start hold 100 wait 500 x1";
      line "wait" "wait 1500" "wait 1500";
      line "shot adds .png" "shot title" "shot title.png";
      line "shot keeps a given extension" "shot /tmp/x.png" "shot /tmp/x.png";
      line "read" "read start_menu" "read start_menu";
      line "status" "status" "status";
      line "blank line" "   " "skip";
      line "comment line" "# open the menu" "skip";
      line "comment after a command" "press START 100 800  # menu"
        "press Start hold 100 wait 800 x1";
      line "the Switch's HOME" "press HOME 100 1500"
        "press Home hold 100 wait 1500 x1";
      line "the Switch's X" "press x" "press X hold 100 wait 500 x1";
      line "the Switch's ZL" "press zl 2000 0" "press ZL hold 2000 wait 0 x1";
      line "the Switch's ZR" "press zr 1500 0" "press ZR hold 1500 wait 0 x1";
      line "unknown button" "press ZX" "error: unknown button \"ZX\"";
      line "dpad needs a direction" "dpad A" "error: \"A\" is not a direction";
      line "dpad count of 0" "dpad UP 0" "error: dpad: N must be at least 1";
      line "not a number" "press A soon"
        "error: press: \"soon\" is not a number of ms";
      line "too many numbers" "press A 1 2 3" "error: press: too many numbers";
      line "a flag without a value" "press A --hold"
        "error: --hold needs a value";
      line "negative wait" "wait -5" "error: wait: \"-5\" is not a number of ms";
      line "unknown command" "tap A" "error: unknown command \"tap A\"";
      line "shot without a name" "shot" "error: unknown command \"shot\"";
      {
        Table_test.name = "a press is its batch, once per tap";
        input =
          (fun () ->
            match Ctl_script.parse_line "dpad DOWN 2" with
            | Ok (Some step) ->
                string_of_int (List.length (Ctl_script.commands step))
            | _ -> "parse failed");
        expectation = "2";
      };
      {
        Table_test.name = "only presses and waits need the lease";
        input =
          (fun () ->
            String.concat " "
              (List.map
                 (fun text ->
                   match Ctl_script.parse_line text with
                   | Ok (Some step) ->
                       string_of_bool (Ctl_script.sends_input step)
                   | _ -> "?")
                 [ "press A"; "wait 5"; "shot x"; "read dialog"; "status" ]));
        expectation = "true true false false false";
      };
    ]
