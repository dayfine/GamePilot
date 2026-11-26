(* The starter option (Plza_story.Starter): its values, and the walk to the
   starter it gives 01.04 (the fork's aimed_at_starter). One fact per case. *)

module S = Plza_story.Starter
module W = Plza_rules.Walk_args

let case name input expectation = { Table_test.name; input; expectation }

(* 01.04's walk to the starter, as its plan writes it. *)
let plan_walk ?(to_starter = true) ?(wait_before_ms = 0) () : W.t =
  {
    move =
      {
        legs = [ { angle_deg = -66.0; walk_ms = 600 } ];
        style = Steer;
        wait_before_ms;
      };
    until = Some (Talk { after_legs = true });
    earliest_end_ms = 0;
    heading_deg = None;
    to_starter;
  }

let aimed ?to_starter ?wait_before_ms tag () =
  match S.of_tag tag with
  | Some s -> W.to_string (S.aimed s (plan_walk ?to_starter ?wait_before_ms ()))
  | None -> "no starter " ^ tag

let named tag () = match S.of_tag tag with Some s -> S.name s | None -> "none"

let cases =
  [
    case "water is Totodile" (named "water") "Totodile";
    case "fire is Tepig" (named "fire") "Tepig";
    case "grass is Chikorita" (named "grass") "Chikorita";
    case "chikorita is not a value" (named "chikorita") "none";
    case "the default is grass" (fun () -> S.tag S.default) "grass";
    case "grass: the plan's legs" (aimed "grass")
      "walk [-66, 600] steer or the starter's own into a talk after the legs";
    case "water: Totodile's walk, -50 degrees steered for 600 ms"
      (aimed "water")
      "walk [-50, 600] steer or the starter's own into a talk after the legs";
    case "fire: Tepig's walk, -34 degrees steered for 600 ms" (aimed "fire")
      "walk [-34, 600] steer or the starter's own into a talk after the legs";
    case "water keeps the plan's wait before"
      (aimed ~wait_before_ms:500 "water")
      "walk [-50, 600] steer after 500 ms or the starter's own into a talk \
       after the legs";
    case "a walk without to_starter keeps its legs"
      (aimed ~to_starter:false "water")
      "walk [-66, 600] steer into a talk after the legs";
  ]

let () = Table_test.run "plza_starter" cases
