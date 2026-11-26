(* A toy game's rules, to prove the engine needs no tile grid and no Pokémon,
   and that a game's rules come from pieces: the engine's zone pose and story
   actions, two toy action sets, and the engine's position beside the toy's
   promises. *)

module Toy_walk = Toy_walk
module Toy_inn = Toy_inn
module Toy_promises = Toy_promises
module Pose = Engine_rules.Zone_pose

module Action = struct
  type t =
    | Story of Engine_rules.Story_action.t
    | Walk of Toy_walk.t
    | Inn of Toy_inn.t

  let to_string = function
    | Story a -> Engine_rules.Story_action.to_string a
    | Walk w -> Toy_walk.to_string w
    | Inn i -> Toy_inn.to_string i
end

module Promised = Engine_rules.Promises.With_position (Pose) (Toy_promises)
module Postconditions = Promised

let ends_at : Action.t -> Pose.t option = function
  | Story _ | Walk _ | Inn _ -> None

let position = Promised.position

(* The sign it promises in sight, alone: the toy's end place. *)
let end_place (p : Postconditions.t) =
  Option.map
    (fun sign ->
      {
        Engine_rules.Promises.position = None;
        promises = { Toy_promises.gold = None; flags = []; sign = Some sign };
      })
    p.promises.sign
