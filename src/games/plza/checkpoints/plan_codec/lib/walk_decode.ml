open Plza_terms.Walk_args
open Engine_plan_codec.Plan_fields
module F = Json_field

(* The "end" that holds the last leg until a scene takes control. *)
let until_scene = "scene"

(* [[turn degrees, walk ms], ...] *)
let leg ~where i : Yojson.Safe.t -> leg = function
  | `List [ `Int turn; `Int walk_ms ] -> { turn = float_of_int turn; walk_ms }
  | _ -> F.fail "%slegs[%d] is not [turn degrees, walk ms]." where i

let legs ~where args =
  match F.field ~where "legs" args with
  | `List rows -> List.mapi (leg ~where) rows
  | _ -> F.fail "%slegs is not a list of legs." where

let not_an_end where =
  F.fail
    "%send must be \"fade_white\", \"fade_black\", \"dialog\", or \"scene\"."
    where

let until_of_word ~where word =
  if word = until_scene then Scene
  else
    match end_event_of_name word with
    | Some event -> Event event
    | None -> not_an_end where

let until ~where args =
  Option.map (until_of_word ~where) (F.string_opt ~where "end" args)

let end_after_ms ~where args until =
  match (optional ~where "end_after_ms" args F.int, until) with
  | None, _ -> 0
  | Some _, None -> F.fail "%send_after_ms needs an \"end\"." where
  | Some ms, Some _ -> ms

let walk ~where args =
  known_fields_only ~where
    [ "legs"; "end"; "held"; "wait_ms"; "end_after_ms" ]
    args;
  let style =
    if F.bool_or ~where ~default:false "held" args then Held else Turn_then_walk
  in
  let move =
    {
      legs = legs ~where args;
      style;
      wait_first_ms =
        Option.value ~default:0 (optional ~where "wait_ms" args F.int);
    }
  in
  let until = until ~where args in
  { move; until; end_after_ms = end_after_ms ~where args until }
