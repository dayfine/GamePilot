(* Claim_gifts.run's Boxes stage, from the Boxes to the main menu (--from boxes
   --stop-at moved), on a scripted console: each gift goes to its own slot of
   Box 1 whichever gifts the run claims, Xerneas (the code's gift) to slot 1
   and Vivillon (the Internet gift) to slot 2, and a taken slot ends the run
   with nothing moved. The run's gifts say which one is in party slot 6: the
   Internet gift when the run claims it (with five in the party it lands
   there, and the code's gift, claimed after it, goes straight to Box 1 slot
   1), the code's gift when the run claims it alone. Also --slot-2-to-1: Box
   1 slot 2 moved to an empty slot 1, as console B's French code-only run
   left Xerneas (2026-11-25).

   The console: the party's six slots in a row over Box 1's first row (six
   columns), the cursor on Box 1 slot 1 when the Boxes open; Up and Down move
   between the party and the box row, Left and Right along a row; Y picks up
   the Pokémon under the cursor, or drops the one held on an empty cell; B
   leaves the Boxes for the main menu. Its frames are captures' probes
   (fixtures/gifts.probes.jsonl): the Boxes are console B's with Xerneas under
   the cursor, their cell's probes swapped for an empty cell's (the fork's
   box-cells/empty-0-4) when the cursor's cell is empty; the main menu is
   tutorial-cards' it-menu-no-card (five Pokémon), its sixth card's probe
   swapped for the fifth's when party slot 6 holds one. One frame per ms. *)

module C = Plza_gifts.Claim_gifts

let frames = Wire.read_image_probes "gifts.probes.jsonl"
let boxes = List.assoc "./mystery-gift/boxes-xerneas-in-box-1.png" frames
let empty_cell = List.assoc "./box-cells/empty-0-4-360p.jpg" frames
let menu = List.assoc "./tutorial-cards/it-menu-no-card.jpg" frames
let is_cell id = String.starts_with ~prefix:"box_cell." id

let boxes_on ~cell_full =
  if cell_full then boxes
  else
    List.map
      (fun (id, r) ->
        if is_cell id then (id, List.assoc id empty_cell) else (id, r))
      boxes

let menu_with ~sixth =
  if not sixth then menu
  else
    List.map
      (fun (id, r) ->
        if id = "main_menu_row.card5" then
          (id, List.assoc "main_menu_row.card4" menu)
        else (id, r))
      menu

type cursor = Party of int | Box of int

type t = {
  mutable ms : int;
  mutable on_boxes : bool;
  mutable cursor : cursor;
  mutable held : string option;
  party6 : string option ref;
  box : string option array;  (** Box 1's first row *)
  mutable ys : int;
}

let cell t =
  match t.cursor with
  | Party 5 -> t.party6
  | Party _ -> ref (Some "party")
  | Box c -> ref t.box.(c)

let probes t =
  if t.on_boxes then boxes_on ~cell_full:(!(cell t) <> None)
  else menu_with ~sixth:(!(t.party6) <> None)

let frame t : Wire.frame =
  { seq = t.ms; t_ms = float_of_int t.ms; probes = probes t }

let along c d = max 0 (min 5 (c + d))

let set t v =
  match t.cursor with
  | Party 5 -> t.party6 := v
  | Party _ -> ()
  | Box c -> t.box.(c) <- v

let y t =
  t.ys <- t.ys + 1;
  match (t.held, !(cell t)) with
  | None, Some p ->
      t.held <- Some p;
      set t None
  | Some p, None ->
      t.held <- None;
      set t (Some p)
  | _ -> ()

let press t (b : Wire.button) =
  if t.on_boxes then
    match (b, t.cursor) with
    | Up, Box c -> t.cursor <- Party c
    | Down, Party c -> t.cursor <- Box c
    | Left, Party c -> t.cursor <- Party (along c (-1))
    | Right, Party c -> t.cursor <- Party (along c 1)
    | Left, Box c -> t.cursor <- Box (along c (-1))
    | Right, Box c -> t.cursor <- Box (along c 1)
    | Y, _ -> y t
    | B, _ -> t.on_boxes <- false
    | _ -> ()

let rec tick t n pred =
  if n <= 0 then None
  else (
    t.ms <- t.ms + 1;
    if pred (frame t) then Some (frame t) else tick t (n - 1) pred)

let command t (c : Wire.command) =
  match c with
  | Press { buttons; hold_ms; cooldown_ms; _ } ->
      List.iter (press t) buttons;
      ignore (tick t (hold_ms + cooldown_ms) (fun _ -> false))
  | Wait { wait_ms } -> ignore (tick t wait_ms (fun _ -> false))

let handle t f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          let answer (v : unit -> a) =
            Some (fun (k : (a, _) continuation) -> continue k (v ()))
          in
          match eff with
          | Effects.Submit cs ->
              answer (fun () ->
                  List.iter (command t) cs;
                  ({ batch_id = "s"; seq = t.ms; t_ms = float_of_int t.ms }
                    : Wire.batch_done))
          | Effects.Await (pred, timeout) ->
              answer (fun () : Effects.awaited ->
                  if pred (frame t) then Holds (frame t)
                  else
                    match tick t timeout pred with
                    | Some f -> Holds f
                    | None -> Timeout)
          | Effects.Now -> answer (fun () -> float_of_int t.ms)
          | Effects.Read -> answer (fun () -> Some (frame t))
          | Effects.Subscribe specs ->
              answer (fun () ->
                  List.map (fun (p : Wire.probe_spec) -> p.id) specs)
          | Effects.Unsubscribe ids -> answer (fun () -> ids)
          | _ -> None);
    }

let native : Wire.box = { x = 0.; y = 0.; w = 1.; h = 1. }

let tile : Switch_home.Home_screen.tile_color =
  { min = (0, 0, 0); max = (0, 0, 0) }

let name = Option.value ~default:"-"

let layout t =
  Printf.sprintf "Box 1: %s %s; party slot 6: %s"
    (name t.box.(0))
    (name t.box.(1))
    (name !(t.party6))

let run ?(from = "boxes") mode ~party6 ~slot1 ~slot2 () =
  let t =
    {
      ms = 0;
      on_boxes = true;
      cursor = Box 0;
      held = None;
      party6 = ref party6;
      box = [| slot1; slot2; None; None; None; None |];
      ys = 0;
    }
  in
  let span : C.span = { from; stop_at = Some "moved"; mode } in
  let outcome =
    handle t (fun () ->
        match
          C.run ~log:ignore ~picture:native
            ~assets:Plza_readers.Blob_assets.file_names ~gift_name:None ~tile
            ~span ~code:C.default_code
        with
        | Ok () -> "ok"
        | Error e -> "error: " ^ e)
  in
  Printf.sprintf "%s; %s; %d Y" outcome (layout t) t.ys

let xerneas = Some "Xerneas"
let vivillon = Some "Vivillon"
let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "box_gifts"
    [
      case "both gifts: Vivillon to slot 2, beside Xerneas"
        (run Both_gifts ~party6:vivillon ~slot1:xerneas ~slot2:None)
        "ok; Box 1: Xerneas Vivillon; party slot 6: -; 2 Y";
      case "the code alone: Xerneas to slot 1"
        (run Code_gift_only ~party6:xerneas ~slot1:None ~slot2:None)
        "ok; Box 1: Xerneas -; party slot 6: -; 2 Y";
      case "the Internet gift alone, Xerneas boxed: Vivillon to slot 2"
        (run Internet_gift_only ~party6:vivillon ~slot1:xerneas ~slot2:None)
        "ok; Box 1: Xerneas Vivillon; party slot 6: -; 2 Y";
      case "the Internet gift first, nothing boxed: Vivillon to slot 2"
        (run Internet_gift_only ~party6:vivillon ~slot1:None ~slot2:None)
        "ok; Box 1: - Vivillon; party slot 6: -; 2 Y";
      case "the code alone, slot 1 taken: nothing moved"
        (run Code_gift_only ~party6:xerneas ~slot1:vivillon ~slot2:None)
        "error: Box 1 slot 1 is not empty; nothing moved, nothing saved; Box \
         1: Vivillon -; party slot 6: Xerneas; 0 Y";
      case "both gifts, slot 2 taken: nothing moved"
        (run Both_gifts ~party6:vivillon ~slot1:xerneas ~slot2:xerneas)
        "error: Box 1 slot 2 is not empty; nothing moved, nothing saved; Box \
         1: Xerneas Xerneas; party slot 6: Vivillon; 0 Y";
      case "slot 2 to slot 1: Xerneas to slot 1"
        (run Box_slot_2_to_1 ~party6:None ~slot1:None ~slot2:xerneas)
        "ok; Box 1: Xerneas -; party slot 6: -; 2 Y";
      case "slot 2 to slot 1, slot 1 taken: nothing moved"
        (run Box_slot_2_to_1 ~party6:None ~slot1:vivillon ~slot2:xerneas)
        "error: Box 1 slot 1 is not empty; nothing moved, nothing saved; Box \
         1: Vivillon Xerneas; party slot 6: -; 0 Y";
      case "slot 2 to slot 1, slot 2 empty: nothing moved"
        (run Box_slot_2_to_1 ~party6:None ~slot1:None ~slot2:None)
        "error: Box 1 slot 2 is empty; nothing moved, nothing saved; Box 1: - \
         -; party slot 6: -; 0 Y";
    ]
