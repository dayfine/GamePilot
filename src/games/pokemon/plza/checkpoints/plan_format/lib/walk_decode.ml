open Plza_rules.Walk_args
open Engine_plan_format.Plan_fields
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
    "%send must be \"fade_white\", \"fade_black\", \"dialog\", \"prompt\", \
     \"talk\", \"talk_after_legs\" or \"scene\"."
    where

let until_of_word ~where word =
  if word = until_scene then Scene
  else if word = "talk" then Talk { after_legs = false }
  else if word = "talk_after_legs" then Talk { after_legs = true }
  else
    match end_event_of_name word with
    | Some event -> Event event
    | None -> not_an_end where

let until ~where args =
  Option.map (until_of_word ~where) (F.string_opt ~where "end" args)

let earliest_end_ms ~where args until =
  match (optional ~where "earliest_end_ms" args F.int, until) with
  | None, _ -> 0
  | Some _, (None | Some (Talk _)) ->
      F.fail "%searliest_end_ms needs an \"end\" other than a talk." where
  | Some ms, Some _ -> ms

let style ~where args =
  match F.string_opt ~where "style" args with
  | None -> Face_then_walk
  | Some name -> (
      match style_of_name name with
      | Some style -> style
      | None -> F.fail "%sstyle must be \"face_then_walk\" or \"steer\"." where)

(* The fork's check: the legs are the starter's with no walk of its own. *)
let to_starter ~where args move =
  let flagged = F.bool_or ~where ~default:false "to_starter" args in
  if flagged && move.legs = [] then
    F.fail "%sto_starter needs the legs of the starter with no walk of its own."
      where
  else flagged

let walk ~where args =
  known_fields_only ~where
    [
      "legs";
      "end";
      "style";
      "wait_before_ms";
      "earliest_end_ms";
      "heading";
      "to_starter";
    ]
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
  {
    move;
    until;
    earliest_end_ms = earliest_end_ms ~where args until;
    heading_deg = Option.map float_of_int (optional ~where "heading" args F.int);
    to_starter = to_starter ~where args move;
  }
