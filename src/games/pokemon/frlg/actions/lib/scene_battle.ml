let run (g : Trainer_battles.game_steps) ~may_lose =
  let fought =
    Trainer_battles.run { g with settle = (fun () -> Ok ()) } ~battles:1
  in
  match fought with
  | Error e -> Error e
  | Ok (Lost _) when may_lose -> Ok ()
  | Ok outcome -> Trainer_battles.failure outcome

let play ~log ~fight ~may_lose =
  run (Trainer_battles.live_game_steps ~log ~fight) ~may_lose
