(* gamepilot ctl [--port N] [--owner LABEL] claim-gifts plza [--code CODE]
     [--code-only] [--from POINT] [--stop-at POINT] [--language TAG]

   Claims PLZA's Mystery Gifts (the Internet's Vivillon, the code's gift,
   CELEBRATE30TH's Xerneas by default), moves the Vivillon from party slot 6
   to Box 1 slot 2, saves and closes the game (Plza_gifts.Claim_gifts, the lab's
   plza_claim_and_bank.sh from the BDSPLab lab tools, its stages 1 to 3). From
   PLZA's overworld with five Pokémon in the party and Box 1 empty. [--from]
   starts on a later screen (a point of Claim_gifts.points: gift-list, card,
   keyboard, boxes, save, ...), [--stop-at] stops on one, the console left
   there; [--code-only] is the script's flag. [--language] is the game's
   (autostory's [--options language=] tags; en by default): the Internet gift
   is found by its name in that language (Claim_gifts.gift_name_template), and
   a language with no name template is refused before any press unless the run
   does not claim that gift. Through a running daemon under
   the input lease (Console_park_command.run_step); the daemon must show the
   whole frame (--viewport native). *)

module C = Plza_gifts.Claim_gifts

let usage_line =
  "      | claim-gifts plza [--code CODE] [--code-only] [--from POINT]\n\
  \        [--stop-at POINT] [--language TAG]  (PLZA: Mystery Gifts claimed,\n\
  \        the Vivillon boxed, saved, closed; TAG: the game's language, en or\n\
  \        fr; POINT: " ^ String.concat " " C.points ^ ")\n"

type flags = { code : string; span : C.span; language : string }

let rec parse f = function
  | [] -> Ok f
  | "--code" :: c :: rest -> parse { f with code = c } rest
  | "--code-only" :: rest ->
      parse { f with span = { f.span with code_only = true } } rest
  | "--from" :: p :: rest ->
      parse { f with span = { f.span with from = p } } rest
  | "--language" :: l :: rest -> parse { f with language = l } rest
  | "--stop-at" :: p :: rest ->
      parse { f with span = { f.span with stop_at = Some p } } rest
  | a :: _ -> Error ("claim-gifts: unknown argument " ^ a)

let defaults =
  {
    code = C.default_code;
    span = { from = "overworld"; stop_at = None; code_only = false };
    language = "en";
  }

let name = "Claim gifts"
let ( let* ) = Result.bind

let upload png =
  match Repo_io.Repo_files.locate png with
  | None -> Error ("claim-gifts: " ^ png ^ " not found above here")
  | Some file ->
      Ok
        (Effects.upload_template
           (In_channel.with_open_bin file In_channel.input_all))

let gift_name png =
  Option.fold ~none:(Ok None)
    ~some:(fun png -> Result.map Option.some (upload png))
    png

let claim f png ~log ~picture =
  let* assets = Plza_series.Templates.upload () in
  let* gift_name = gift_name png in
  C.run ~log ~picture ~assets ~gift_name
    ~tile:Plza_autostory.Game_reload.tile_color ~span:f.span ~code:f.code

let checked args =
  let* f = parse defaults args in
  let* () = C.check f.span in
  let* png =
    Result.map_error
      (fun e -> "claim-gifts: " ^ e)
      (C.gift_name_template ~language:f.language f.span)
  in
  Ok (f, png)

let main ~port ~owner = function
  | "plza" :: args ->
      Result.map
        (fun (f, png) ->
          Console_park_command.run_step ~port ~owner ~name (claim f png))
        (checked args)
  | _ -> Error "ctl: claim-gifts takes a game: plza"
