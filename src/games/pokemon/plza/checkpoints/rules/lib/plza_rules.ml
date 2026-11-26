module Walk_args = Walk_args

module Pose = struct
  type zone = { place : string; spot : string option }
  type t = zone
  type observed = zone

  let matches pose observed =
    pose.place = observed.place
    && (pose.spot = None || pose.spot = observed.spot)

  let to_string { place; spot } =
    match spot with Some s -> place ^ "/" ^ s | None -> place

  let observed_to_string = to_string
end

module Action = struct
  type t = Walk of Walk_args.t

  let to_string = function Walk w -> Walk_args.to_string w
end

module Screen_signature = Screen_signature

module Postconditions = struct
  type t = { place : Screen_signature.t option }
  type reads = Screen_signature.t

  let judge_place read known =
    Engine_postcondition.Postcondition.judge "place"
      ~expected:(Screen_signature.to_string known)
      ~read:(Screen_signature.to_string read)
      (Screen_signature.confirmed ~known read)

  let check p read = Option.to_list (Option.map (judge_place read) p.place)

  let to_lines p =
    Option.fold ~none:[]
      ~some:(fun s -> [ "place " ^ Screen_signature.to_string s ])
      p.place
end

(* PLZA reads no position: a walk names no end, and no zone is promised. *)
let ends_at (Action.Walk _) = None
let position (_ : Postconditions.t) = None

let end_place (p : Postconditions.t) =
  Option.map (fun _ -> p) p.Postconditions.place
