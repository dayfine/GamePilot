open Plza_rules.Walk_args

type t = Chikorita | Tepig | Totodile

let default = Chikorita
let all = [ Chikorita; Tepig; Totodile ]

let tag = function
  | Chikorita -> "grass"
  | Tepig -> "fire"
  | Totodile -> "water"

let name = function
  | Chikorita -> "Chikorita"
  | Tepig -> "Tepig"
  | Totodile -> "Totodile"

let of_tag t = List.find_opt (fun s -> tag s = t) all

(* The fork's walks to Totodile and Tepig: one leg held ("held": true, our
   Steer) for 600 ms. *)
let held_ms = 600

let steered angle_deg =
  {
    legs = [ { angle_deg; walk_ms = held_ms } ];
    style = Steer;
    wait_before_ms = 0;
  }

let move = function
  | Totodile -> Some (steered (-50.0))
  | Tepig -> Some (steered (-34.0))
  | Chikorita -> None

(* The starter's walk in place of the legs, the wait before kept. *)
let aimed starter walk =
  match (walk.to_starter, move starter) with
  | true, Some m ->
      { walk with move = { m with wait_before_ms = walk.move.wait_before_ms } }
  | _ -> walk

let decls : Run_options.declared list =
  [
    {
      key = "starter";
      value = One_of (List.map tag all);
      presence = Optional;
      doc =
        "the starter 01.04 picks: grass (Chikorita), fire (Tepig) or water \
         (Totodile) (not given: grass, the plan's walk)";
    };
  ]
