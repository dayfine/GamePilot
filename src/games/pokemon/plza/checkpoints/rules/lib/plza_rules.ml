module Walk_args = Walk_args
module Pose = Engine_rules.Zone_pose

module Action = struct
  type t = Walk of Walk_args.t

  let to_string = function Walk w -> Walk_args.to_string w
end

module Screen_signature = Screen_signature

type readable_flag = Mystery_gift

let readable_flags = [ ("mystery_gift", Mystery_gift) ]

module Postconditions = struct
  type t = { place : Screen_signature.t option; flags : string list }

  type reads = {
    screen : Screen_signature.t;
    flags_read : (string * bool) list;
  }

  let judge_place read known =
    Engine_postcondition.Postcondition.judge "place"
      ~expected:(Screen_signature.to_string known)
      ~read:(Screen_signature.to_string read)
      (Screen_signature.confirmed ~known read)

  (* As a Pokémon flag is checked (Postcondition_check): set, clear, or not
     read. *)
  let judge_flag read flag =
    let what = "flag " ^ flag in
    match List.assoc_opt flag read.flags_read with
    | None -> Engine_postcondition.Postcondition.not_read what
    | Some set ->
        Engine_postcondition.Postcondition.judge what ~expected:"set"
          ~read:(if set then "set" else "clear")
          set

  let check p read =
    Option.to_list (Option.map (judge_place read.screen) p.place)
    @ List.map (judge_flag read) p.flags

  let to_lines p =
    Option.fold ~none:[]
      ~some:(fun s -> [ "place " ^ Screen_signature.to_string s ])
      p.place
    @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]
end

(* PLZA reads no position: a walk names no end, and no zone is promised. *)
let ends_at (Action.Walk _) = None
let position (_ : Postconditions.t) = None

let end_place (p : Postconditions.t) =
  if Option.is_some p.place || p.flags <> [] then Some p else None
