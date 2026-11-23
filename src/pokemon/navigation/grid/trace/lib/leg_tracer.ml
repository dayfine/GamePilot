type t = {
  emit : string -> unit;
  mutable checkpoint : string;
  mutable event : string;
  mutable legs : int;
  mutable leg : Leg_record.t option;
}

type walk = {
  chunks : int;
  walked_ms : int;
  wild_battles : int;
  tapped : int option;
}

let create emit = { emit; checkpoint = ""; event = ""; legs = 0; leg = None }

let end_leg tracer ?note end_tiles known =
  match tracer.leg with
  | None -> ()
  | Some record ->
      tracer.leg <- None;
      tracer.emit (Leg_record.to_line { record with end_tiles; known; note })

let end_event tracer = end_leg tracer [] Leg_record.End_known.Unknown

let begin_event tracer ~checkpoint ~event =
  end_event tracer;
  tracer.checkpoint <- checkpoint;
  tracer.event <- event;
  tracer.legs <- 0

(* The record of a leg that has only just started. *)
let started tracer plan : Leg_record.t =
  {
    checkpoint = tracer.checkpoint;
    event = tracer.event;
    leg = tracer.legs;
    plan;
    moved = None;
    chunks = 0;
    walked_ms = 0;
    end_tiles = [];
    known = Unknown;
    interrupts = [];
    note = None;
  }

let begin_leg tracer plan =
  end_event tracer;
  tracer.legs <- tracer.legs + 1;
  tracer.leg <- Some (started tracer plan)

let open_leg tracer =
  Option.map (fun (record : Leg_record.t) -> record.plan) tracer.leg

let add_walk (record : Leg_record.t) walk =
  let battles =
    List.init walk.wild_battles (fun _ -> Leg_record.Interrupt.Wild_battle)
  in
  let moved =
    match walk.tapped with
    | None -> record.moved
    | Some tapped -> Some (Option.value record.moved ~default:0 + tapped)
  in
  {
    record with
    chunks = record.chunks + walk.chunks;
    walked_ms = record.walked_ms + walk.walked_ms;
    interrupts = record.interrupts @ battles;
    moved;
  }

let walked tracer walk =
  tracer.leg <- Option.map (fun record -> add_walk record walk) tracer.leg

let interrupted tracer interrupt =
  tracer.leg <-
    Option.map
      (fun (record : Leg_record.t) ->
        { record with interrupts = record.interrupts @ [ interrupt ] })
      tracer.leg
