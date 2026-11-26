(* Ace_trigger on a fake box screen: 14 boxes of 30 slots, the hand on the
   title or a slot, SELECT's quick hand, a held Pokémon, shifts as pokefirered
   does them (A on a slot while holding swaps; on an empty one places), and
   the second shift with 0x0351 running the code. *)

open Frlg_actions
module T = Ace_trigger

let ace = "0x0351"

type fake = {
  boxes : string option array array;
  titles : string array;
  mutable box : int;
  mutable on_title : bool;
  mutable slot : int;  (** 0-based *)
  mutable quick : bool;
  mutable held : string option;
  mutable shifts_with_ace : int;
  mutable alive : bool;
  mutable trace : string list;
  quick_lost : bool;  (** SELECT does not turn the hand orange *)
  crash : bool;  (** the code stops the game *)
}

let note f s = f.trace <- s :: f.trace
let here f = f.boxes.(f.box).(f.slot)
let set f v = f.boxes.(f.box).(f.slot) <- v

let a_on_slot f =
  match (f.held, here f) with
  | None, Some m when f.quick ->
      f.held <- Some m;
      set f None
  | None, _ -> ()
  | Some h, under ->
      if under <> None && (h = ace || under = Some ace) then (
        f.shifts_with_ace <- f.shifts_with_ace + 1;
        if f.crash && f.shifts_with_ace = 2 then f.alive <- false);
      set f (Some h);
      f.held <- under

let press f (b : Wire.button) =
  note f (Wire.string_of_button b);
  match b with
  | Up when not f.on_title ->
      if f.slot < 6 then f.on_title <- true else f.slot <- f.slot - 6
  | Down when f.on_title ->
      f.on_title <- false;
      f.slot <- 2
  | Right when f.on_title -> f.box <- (f.box + 1) mod 14
  | Left when f.on_title -> f.box <- (f.box + 13) mod 14
  | Down -> f.slot <- f.slot + 6
  | Right -> f.slot <- f.slot + 1
  | Left -> f.slot <- f.slot - 1
  | Select -> if not f.quick_lost then f.quick <- not f.quick
  | A when not f.on_title -> a_on_slot f
  | _ -> ()

let steps f : T.game_steps =
  {
    open_move_pokemon =
      (fun () ->
        note f "open";
        f.on_title <- false;
        f.slot <- 0);
    press = press f;
    read_title =
      (fun cs ->
        let t = f.titles.(f.box) in
        if f.alive && List.mem t cs then Some t else None);
    slot_empty = (fun () -> Some (here f = None));
    ace_at_hand = (fun () -> here f = Some ace);
    hand_quick = (fun () -> Some f.quick);
    await_alive = (fun name -> f.alive && f.titles.(f.box) = name);
    close = (fun () -> note f "close");
  }

let trigger : T.trigger =
  { box3_title = "EE …l‘"; partner_box = 1; partner_slot = 1 }

(* [partner_at]: the partner's box and slot (from 1); [None]: nowhere. *)
let make ?(partner_at = Some (1, 1)) ?(box = 2) ?(quick_lost = false)
    ?(crash = false) () =
  let boxes = Array.init 14 (fun _ -> Array.make 30 None) in
  boxes.(2).(0) <- Some ace;
  Option.iter
    (fun (b, s) -> boxes.(b - 1).(s - 1) <- Some "magikarp")
    partner_at;
  let titles = Array.init 14 (fun i -> Printf.sprintf "B%d" (i + 1)) in
  titles.(2) <- trigger.box3_title;
  {
    boxes;
    titles;
    box;
    on_title = false;
    slot = 0;
    quick = false;
    held = None;
    shifts_with_ace = 0;
    alive = true;
    trace = [];
    quick_lost;
    crash;
  }

let run ?(trigger = trigger) f =
  let outcome =
    match T.run (steps f) ~log:ignore trigger with
    | () -> "ok"
    | exception Menu_input.Action_failed c -> c.code
  in
  Printf.sprintf "%s: %s; shifts %d, box3 %s %s, quick %b" outcome
    (String.concat " " (List.rev f.trace))
    f.shifts_with_ace
    (Option.value ~default:"-" f.boxes.(2).(0))
    (Option.value ~default:"-" f.boxes.(2).(1))
    f.quick

let case ?trigger name f expectation : Table_test.case =
  { name; input = (fun () -> run ?trigger (f ())); expectation }

let cases =
  [
    case "a partner already in Box 3 slot 2: the two shifts"
      (fun () -> make ~partner_at:(Some (3, 2)) ())
      "ok: open Up Down Left Left Select A Right A A Left A Select Up close; \
       shifts 2, box3 0x0351 magikarp, quick false";
    case "the partner fetched from Box 1 slot 1, the screen opened on Box 1"
      (fun () -> make ~box:0 ())
      "ok: open Up Right Right Down Left Up Left Left Down Left Left Select A \
       Up Right Right Down Left A Up Down Left Left A Right A A Left A Select \
       Up close; shifts 2, box3 0x0351 magikarp, quick false";
    case
      ~trigger:{ trigger with partner_box = 5; partner_slot = 9 }
      "the partner fetched from Box 5 slot 9: two scrolls right, down a row"
      (fun () -> make ~partner_at:(Some (5, 9)) ())
      "ok: open Up Down Left Up Right Right Down Down Select A Up Up Left Left \
       Down Left A Up Down Left Left A Right A A Left A Select Up close; \
       shifts 2, box3 0x0351 magikarp, quick false";
    case "no Pokémon in the partner's slot: refused before a SELECT"
      (fun () -> make ~partner_at:None ())
      "ace_partner_missing: open Up Down Left Up Left Left Down Left Left; \
       shifts 0, box3 0x0351 -, quick false";
    case "SELECT does not take: no A on 0x0351"
      (fun () -> make ~partner_at:(Some (3, 2)) ~quick_lost:true ())
      "ace_hand_not_quick: open Up Down Left Left Select; shifts 0, box3 \
       0x0351 magikarp, quick false";
    case "the game stops after the shifts"
      (fun () -> make ~partner_at:(Some (3, 2)) ~crash:true ())
      "ace_game_stopped: open Up Down Left Left Select A Right A A Left A \
       Select Up; shifts 2, box3 0x0351 magikarp, quick false";
  ]

let () = Table_test.run "ace_trigger" cases
