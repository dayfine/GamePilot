(* A toy game's rules, to prove the engine needs no tile grid and no Pokémon:
   the player stands in a zone (a place, and maybe a spot in it), its own
   kinds are a walk that holds a direction until a landmark shows and a rest
   at an inn, and a checkpoint promises gold and flags. *)

open Engine_promise

module Pose = struct
  type t = { place : string; spot : string option }
  type observed = t

  (* A pose without a spot holds anywhere in its place. *)
  let matches pose observed =
    pose.place = observed.place
    && (pose.spot = None || pose.spot = observed.spot)
end

module Kind = struct
  type t = Walk of { toward : string; until : string } | Rest
end

module Promises = struct
  type t = { gold : Count.t option; flags : string list }

  (* What the game read: the gold now and at the start, and each flag read. *)
  type reads = { gold_now : int option; start : int option; set : string list }

  let check_gold (p : t) reads =
    match (p.gold, reads.gold_now) with
    | None, _ -> []
    | Some _, None -> [ Promise.not_read "gold" ]
    | Some count, Some read ->
        [ Promise.count "gold" count ~start:reads.start ~read ]

  let check_flag reads flag =
    let set = List.mem flag reads.set in
    Promise.judge ("flag " ^ flag) ~expected:"set"
      ~read:(if set then "set" else "clear")
      set

  let check p reads = check_gold p reads @ List.map (check_flag reads) p.flags
end
