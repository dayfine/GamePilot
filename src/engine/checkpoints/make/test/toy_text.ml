open Toy_terms
module T = Toy_terms

let pose (p : Pose.t) =
  match p.spot with Some s -> p.place ^ "/" ^ s | None -> p.place

let observed = pose

let kind : Kind.t -> string = function
  | Walk { toward; until } -> Printf.sprintf "walk %s until %s" toward until
  | Rest -> "rest"

let postconditions (p : Promises.t) =
  Option.fold ~none:[]
    ~some:(fun c -> [ "gold " ^ Engine_promise.Count.text c ])
    p.gold
  @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]
