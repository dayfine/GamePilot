(* gamepilot ctl [--port N] [--owner LABEL] home-boxes plza

   Opens Pokémon HOME on Legends: Z-A from the Switch's HOME menu and logs
   the box number and HOME's box, moving nothing (Pokemon_home.Home_bank's
   Look): a look at the boxes before pokemon_home.bank-plza banks the gifts, which
   is the one way to move them. HOME is left open on the boxes, unsaved.
   Through a running daemon under the input lease
   (Console_park_command.run_step); the daemon must show the whole frame
   (--viewport native). The templates are pokemon_home.bank-plza's
   (Plza_bank_home_series.Home_templates). *)

let usage_line =
  "      | home-boxes plza  (Pokémon HOME opened on PLZA: the box number and\n\
  \        HOME's box logged, nothing moved, HOME left open)\n"

let run ~port ~owner =
  Result.map
    (fun (t : Plza_bank_home.Bank_home_game.templates) ->
      Console_park_command.run_step ~port ~owner ~name:"Look at HOME's boxes"
        (fun ~log ~picture ->
          Pokemon_home.Home_bank.run ~log ~picture t.home Look))
    (Plza_bank_home_series.Home_templates.load ())

let main ~port ~owner = function
  | [ "plza" ] -> run ~port ~owner
  | _ -> Error "ctl: home-boxes takes a game: plza"
