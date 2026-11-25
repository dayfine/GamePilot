open Plza_rules.Walk_args
open Engine_plan_codec.Plan_fields
module F = Json_field

(* The "end" that holds the last leg until a scene takes control. *)
let until_scene = "scene"

(* [[angle degrees, walk ms], ...] *)
let leg ~where i : Yojson.Safe.t -> leg = function
  | `List [ `Int angle; `Int walk_ms ] ->
      { angle_deg = float_of_int angle; walk_ms }
  | _ -> F.fail "%slegs[%d] is not [angle degrees, walk ms]." where i

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

let earliest_end_ms ~where args until =
  match (optional ~where "earliest_end_ms" args F.int, until) with
  | None, _ -> 0
  | Some _, None -> F.fail "%searliest_end_ms needs an \"end\"." where
  | Some ms, Some _ -> ms

let style ~where args =
  match F.string_opt ~where "style" args with
  | None -> Face_then_walk
  | Some name -> (
      match style_of_name name with
      | Some style -> style
      | None -> F.fail "%sstyle must be \"face_then_walk\" or \"steer\"." where)

let walk ~where args =
  known_fields_only ~where
    [ "legs"; "end"; "style"; "wait_before_ms"; "earliest_end_ms" ]
    args;
  let move =
    {
      legs = legs ~where args;
      style = style ~where args;
      wait_before_ms =
        Option.value ~default:0 (optional ~where "wait_before_ms" args F.int);
    }
  in
  let until = until ~where args in
  { move; until; earliest_end_ms = earliest_end_ms ~where args until }
