(* The toy's promises: gold gained since the start, and flags set. *)

open Engine_postcondition

type t = { gold : Count.t option; flags : string list }

(* What the game read: the gold now and at the start, and each flag read. *)
type reads = { gold_now : int option; start : int option; set : string list }

let check_gold (p : t) reads =
  match (p.gold, reads.gold_now) with
  | None, _ -> []
  | Some _, None -> [ Postcondition.not_read "gold" ]
  | Some count, Some read ->
      [ Postcondition.count "gold" count ~start:reads.start ~read ]

let check_flag reads flag =
  let set = List.mem flag reads.set in
  Postcondition.judge ("flag " ^ flag) ~expected:"set"
    ~read:(if set then "set" else "clear")
    set

let check p reads = check_gold p reads @ List.map (check_flag reads) p.flags
