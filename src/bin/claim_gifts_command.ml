(* gamepilot ctl [--port N] [--owner LABEL] claim-gifts plza [--code CODE]
     [--code-only] [--from POINT] [--stop-at POINT]

   Claims PLZA's Mystery Gifts (the Internet's Vivillon, the code's gift,
   CELEBRATE30TH's Xerneas by default), moves the Vivillon from party slot 6
   to Box 1 slot 2, saves and closes the game (Plza_gifts.Claim_gifts, the lab's
   plza_claim_and_bank.sh from the BDSPLab lab tools, its stages 1 to 3). From
   PLZA's overworld with five Pokémon in the party and Box 1 empty. [--from]
   starts on a later screen (a point of Claim_gifts.points: gift-list, card,
   keyboard, boxes, save, ...), [--stop-at] stops on one, the console left
   there; [--code-only] is the script's flag. Through a running daemon under
   the input lease (Console_park_command.run_step); the daemon must show the
   whole frame (--viewport native). *)

module C = Plza_gifts.Claim_gifts

let usage_line =
  "      | claim-gifts plza [--code CODE] [--code-only] [--from POINT]\n\
  \        [--stop-at POINT]  (PLZA: Mystery Gifts claimed, the Vivillon\n\
  \        boxed, saved, closed; POINT: " ^ String.concat " " C.points ^ ")\n"

type flags = { code : string; span : C.span }

let rec parse f = function
  | [] -> Ok f
  | "--code" :: c :: rest -> parse { f with code = c } rest
  | "--code-only" :: rest ->
      parse { f with span = { f.span with code_only = true } } rest
  | "--from" :: p :: rest ->
      parse { f with span = { f.span with from = p } } rest
  | "--stop-at" :: p :: rest ->
      parse { f with span = { f.span with stop_at = Some p } } rest
  | a :: _ -> Error ("claim-gifts: unknown argument " ^ a)

let defaults =
  {
    code = C.default_code;
    span = { from = "overworld"; stop_at = None; code_only = false };
  }

let name = "Claim gifts"
let gift_name_png = "src/games/pokemon/plza/assets/gift-name-vivillon.png"

let gift_name () =
  match Repo_io.Repo_files.locate gift_name_png with
  | None -> Error ("claim-gifts: " ^ gift_name_png ^ " not found above here")
  | Some file ->
      Ok
        (Effects.upload_template
           (In_channel.with_open_bin file In_channel.input_all))

let ( let* ) = Result.bind

let claim f ~log ~picture =
  let* assets = Plza_templates.upload () in
  let* gift_name = gift_name () in
  C.run ~log ~picture ~assets ~gift_name
    ~tile:Plza_autostory.Game_reload.tile_color ~span:f.span ~code:f.code

let checked args =
  let* f = parse defaults args in
  let* () = C.check f.span in
  Ok f

let main ~port ~owner = function
  | "plza" :: args ->
      Result.map
        (fun f -> Console_park_command.run_step ~port ~owner ~name (claim f))
        (checked args)
  | _ -> Error "ctl: claim-gifts takes a game: plza"
