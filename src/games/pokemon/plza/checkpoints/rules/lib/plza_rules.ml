module Walk_args = Walk_args

module Pose = struct
  type zone = { place : string; spot : string option }
  type t = zone
  type observed = zone

  let matches pose observed =
    pose.place = observed.place
    && (pose.spot = None || pose.spot = observed.spot)
end

module Action = struct
  type t = Walk of Walk_args.t
end

module Postconditions = struct
  type t = unit
  type reads = unit

  let check () () = []
end

(* PLZA reads no position: a walk names no end, and nothing is promised. *)
let ends_at (Action.Walk _) = None
let position () = None
