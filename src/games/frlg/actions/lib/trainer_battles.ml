module B = Frlg_battle
module Failure = Pokemon_engine.Failure

type outcome = Won of int | Lost of { battle : int; why : string }

type game_steps = {
  await_battle : unit -> (unit, Failure.cause) result;
  fight : B.Battle_script.t -> B.Scripted_battle.outcome;
  settle : unit -> (unit, Failure.cause) result;
  log : string -> unit;
}

let lead_moves = [ 0; 1; 2; 3 ]

let script =
  B.Battle_script.make ~learn:Keep_moves ~use_next:false
    (Attack { slots = lead_moves; target = Default })

let fight_one (g : game_steps) ~battle ~battles =
  Result.map
    (fun () ->
      let outcome = g.fight script in
      g.log
        (Printf.sprintf "Trainer battle %d/%d: %s" battle battles
           (B.Scripted_battle.describe outcome));
      outcome)
    (g.await_battle ())

let rec from (g : game_steps) ~battle ~battles =
  if battle > battles then Result.map (fun () -> Won battles) (g.settle ())
  else
    match fight_one g ~battle ~battles with
    | Error e -> Error e
    | Ok (Failed { why; _ }) -> Ok (Lost { battle; why })
    | Ok (Over _) -> from g ~battle:(battle + 1) ~battles

let run g ~battles = from g ~battle:1 ~battles

let failure = function
  | Won _ -> Ok ()
  | Lost { battle; why } ->
      Error
        (Failure.cause "battle_lost"
           (Printf.sprintf "trainer battle %d: %s" battle why))

let live_game_steps ~log ~fight =
  {
    await_battle =
      (fun () -> Scene_looks.until_battle ~label:"trainer battle" ~log);
    fight;
    settle =
      (fun () ->
        Scene_looks.settle Talk ~label:"after the battles" ~battle_ends:false
          ~log);
    log;
  }

let play ~log ~fight ~battles =
  Result.bind (run (live_game_steps ~log ~fight) ~battles) failure
