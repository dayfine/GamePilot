(* gamepilot ctl [--port N] [--owner LABEL] claim-gifts plza [--code CODE]
     [--from code|boxes] [--stop-at gift-list]

   Claims PLZA's Mystery Gifts (the Internet's Vivillon, the code's gift,
   CELEBRATE30TH's Xerneas by default), moves the Vivillon from party slot 6
   to Box 1 slot 2, saves and closes the game (Plza_gifts.Claim_gifts, the lab's
   plza_claim_and_bank.sh from the BDSPLab lab tools, its stages 1 to 3). From
   PLZA's overworld with five Pokémon in the party and Box 1 empty. [--from]
   starts later, as the script's --code-only and --from-boxes; [--stop-at
   gift-list] stops once the Internet gift list is open, having claimed
   nothing. Through a running daemon under the input lease
   (Console_park_command.run_step); the
   daemon must show the whole frame (--viewport native). *)

module C = Plza_gifts.Claim_gifts

let usage_line =
  "      | claim-gifts plza [--code CODE] [--from code|boxes] [--stop-at \
   gift-list]\n\
  \        (PLZA: Mystery Gifts claimed, the Vivillon boxed, saved, closed)\n"

type flags = { code : string; start : C.start; stop_at_list : bool }

let rec parse f = function
  | [] -> Ok f
  | "--code" :: c :: rest -> parse { f with code = c } rest
  | "--from" :: "code" :: rest -> parse { f with start = C.From_code } rest
  | "--from" :: "boxes" :: rest -> parse { f with start = C.From_boxes } rest
  | "--stop-at" :: "gift-list" :: rest ->
      parse { f with stop_at_list = true } rest
  | a :: _ -> Error ("claim-gifts: unknown argument " ^ a)

let defaults =
  { code = C.default_code; start = C.From_internet; stop_at_list = false }

let name = "Claim gifts"

let claim f ~log ~picture =
  Result.bind (Plza_templates.upload ()) (fun assets ->
      C.run ~log ~picture ~assets ~tile:Plza_autostory.Game_reload.tile_color
        ~start:f.start ~stop_at_list:f.stop_at_list ~code:f.code)

let main ~port ~owner = function
  | "plza" :: args ->
      Result.map
        (fun f -> Console_park_command.run_step ~port ~owner ~name (claim f))
        (parse defaults args)
  | _ -> Error "ctl: claim-gifts takes a game: plza"
