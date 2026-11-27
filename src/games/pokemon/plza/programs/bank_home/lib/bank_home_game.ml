module Failure = Engine_run.Failure
module Game = Plza_engine.Game
module Plan = Plza_engine.Plan
module Title = Switch.Home_title
module Tile = Plza_readers.Switch_home_tile

type templates = {
  home : Pokemon_home.Home_bank.templates;
  plza_title : string;
}

let action = "bank_in_home"

let check_event (event : Plan.event) =
  match (event.kind, event.way) with
  | Named_action [], Some way when way = action -> Ok ()
  | Named_action _, Some way when way = action ->
      Error
        (event.id ^ ": " ^ action
       ^ " takes no args: its moves are the gift catalog's")
  | _ -> Error (event.id ^ ": bank-home's plans name only " ^ action)

let check_plan (plan : Plan.t) =
  match plan.checkpoint.events with
  | [] -> Error (plan.checkpoint.checkpoint_id ^ ": no " ^ action ^ " event")
  | events ->
      List.fold_left
        (fun acc event -> Result.bind acc (fun () -> check_event event))
        (Ok ()) events

(* The walk along HOME's tile row, as Pokemon_home.Home_launch walks it to
   Pokémon HOME's tile. *)
let walk : Title.walk =
  {
    first = { button = Home; hold_ms = 100; cooldown_ms = 1000 };
    next = { button = Right; hold_ms = 80; cooldown_ms = 600 };
    tiles = 8;
  }

let title_read_ms = 1500

let title_shows () =
  match Effects.await ~timeout_ms:title_read_ms Tile.on_plza_tile with
  | Holds _ -> true
  | Timeout -> false

let find_plza_tile ~log =
  Title.find_tile
    { title_shows; press = Switch.Timed_press.press; log }
    walk ~name:"Legends: Z-A"

let start_check ~log (t : templates) =
  let title = Effects.upload_template t.plza_title in
  match
    Effects.with_probes (Tile.probes ~title) (fun () -> find_plza_tile ~log)
  with
  | Ok _ -> Ok ()
  | Error e -> Error (Failure.cause ~repeats:true "home_tile_not_found" e)

let bad_args (event : Plan.event) detail =
  Error (Failure.cause ~repeats:true "bad_args" (event.id ^ ": " ^ detail))

let bank ~log ~picture ~moves (t : templates) (event : Plan.event) = function
  | [] ->
      List.iter log moves.Catalog_moves.skipped;
      Result.map_error
        (Failure.cause "home_bank_failed")
        (Pokemon_home.Home_bank.run ~log ~picture t.home
           (Bank { moves = moves.moves; on_failure = Stop_open }))
  | (key, _) :: _ -> bad_args event (key ^ " is not an arg of " ^ action)

let no_handler what () =
  Error
    (Failure.cause ~repeats:true "no_handler"
       ("bank-home runs " ^ action ^ " only, no " ^ what))

let make ~log ~picture ~moves t : Game.t =
  {
    run_own = (fun _ _ -> no_handler "walk" ());
    run_builtin = (fun _ -> no_handler "talk, answer, scene or save" ());
    game_actions = [ (action, bank ~log ~picture ~moves t) ];
    flag_holds = (fun _ -> false);
    position = (fun () -> None);
    between_rounds = (fun () -> Ok ());
    save = no_handler ("save (Pokémon HOME saves inside " ^ action ^ ")");
    reload = no_handler "reload";
    log;
  }
