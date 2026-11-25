open Toy_rules
module T = Toy_rules

let pose (p : Pose.t) =
  match p.spot with Some s -> p.place ^ "/" ^ s | None -> p.place

let observed = pose

let action : Action.t -> string = function
  | Walk { toward; until } -> Printf.sprintf "walk %s until %s" toward until
  | Rest -> "rest"

let postconditions (p : Postconditions.t) =
  Option.fold ~none:[]
    ~some:(fun c -> [ "gold " ^ Engine_postcondition.Count.text c ])
    p.gold
  @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]
