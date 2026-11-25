(* The Pokémon grid rules' own flags: gamepilot checkpoint's, which a series'
   runs share, and the series' --make-room; parsed through
   Checkpoints_flags' game hooks. *)

type checkpoint_flags = {
  state : string option;
  port : int;
  log_file : string option;
  party : string;
  center : string option;
  walk : bool;
  end_check_only : bool;
  grind_cap : int option;
}

let checkpoint_defaults =
  {
    state = None;
    port = Live.default_port;
    log_file = None;
    party = "";
    center = None;
    walk = false;
    end_check_only = false;
    grind_cap = None;
  }

type series = { common : checkpoint_flags; make_room : string option }
type flags = series Checkpoints_flags.flags

let common_flag f c = { f with common = c f.common }

let switch f = function
  | "--walk" -> Some (common_flag f (fun c -> { c with walk = true }))
  | "--end-check-only" ->
      Some (common_flag f (fun c -> { c with end_check_only = true }))
  | _ -> None

let valued f name v =
  match name with
  | "--party" -> Some (Ok (common_flag f (fun c -> { c with party = v })))
  | "--grind-battles" -> (
      match int_of_string_opt v with
      | Some n when n > 0 ->
          Some (Ok (common_flag f (fun c -> { c with grind_cap = Some n })))
      | _ -> Some (Error ("bad --grind-battles " ^ v)))
  | "--make-room" -> Some (Ok { f with make_room = Some v })
  | "--center" ->
      Some (Ok (common_flag f (fun c -> { c with center = Some v })))
  | _ -> None

let series : series Checkpoints_flags.game_flags =
  {
    game_defaults =
      { common = { checkpoint_defaults with port = 0 }; make_room = None };
    game_switch = switch;
    game_valued = valued;
  }

let defaults = Checkpoints_flags.defaults series
let parse = Checkpoints_flags.parse series

let usage =
  "  gamepilot checkpoints PLAN_DIR|--program ID --from ID --to ID --mode \
   testing|verification\n\
  \      [--runs N] [--states DIR] [--runs-dir DIR] [--daemon PATH]\n\
  \      [--mgba-port N] [--port N] [--party SPECIES,...] [--center TOWN] \
   [--walk]\n\
  \      [--end-check-only] [--grind-battles N] [--max-rounds N] [--watch]\n\
  \      [--watch-port N] [--listen ADDR]\n\
  \      [--backend mgba|switch --serial PORT --capture DEVICE]\n\
  \      [--replay VIDEO] [--save-after-pass|--no-save-after-pass]\n\
  \      [--record|--no-record] [--keepawake SECONDS] [--speed S] [--make-room \
   MAP]\n\
  \      [--viewport nso-gba|native|x,y,w,h]   (Switch: where the game picture \
   sits; the program's by default)\n\
  \      [--from-event ID|N [--to-event ID|N]]   (mGBA, testing, one checkpoint)\n\
  \  gamepilot checkpoints PLAN_DIR|--program ID --preflight --from ID \
   [--backend ...]\n"
