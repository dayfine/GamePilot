(* Mystery_gift.choose_gift on console B's Internet gift list
   (readers/test/fixtures/gifts.probes.jsonl: four gifts, the cursor on the
   first, Vivillon the 4th), played by a scripted console: each Down moves the
   white item one down (its probes' results swapped), A is counted. The gift
   is found by its name, the cursor read on it, then A; a cursor that does not
   move ends it with no A. One frame per ms. *)

let frames = Wire.read_image_probes "gifts.probes.jsonl"
let list = List.assoc "./mystery-gift/gift-list-cursor-on-1.png" frames
let menu = List.assoc "./tutorial-cards/it-menu-no-card.jpg" frames
let item k = Printf.sprintf "mystery_gift.item%d" k

(* The list with the white item [k]: item 0's result and item k's swapped. *)
let cursor_on k probes =
  List.map
    (fun (id, r) ->
      if id = item 0 then (id, List.assoc (item k) list)
      else if id = item k then (id, List.assoc (item 0) list)
      else (id, r))
    probes

type t = {
  mutable ms : int;
  mutable probes : (string * Wire.probe_result) list;
  mutable presses : string list;
  mutable cursor : int;
  moves : bool;
}

let frame t : Wire.frame =
  { seq = t.ms; t_ms = float_of_int t.ms; probes = t.probes }

let press t b =
  t.presses <- Wire.string_of_button b :: t.presses;
  if b = Wire.Down && t.moves then (
    t.cursor <- t.cursor + 1;
    t.probes <- cursor_on t.cursor list)

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
          | _ -> None);
    }

let run ?(moves = true) probes () =
  let t = { ms = 0; probes; presses = []; cursor = 0; moves } in
  let outcome =
    handle t (fun () ->
        match Plza_gifts.Mystery_gift.choose_gift ~log:ignore with
        | Ok () -> "ok"
        | Error e -> "error: " ^ e)
  in
  let presses =
    match List.rev t.presses with [] -> "no press" | l -> String.concat " " l
  in
  outcome ^ "; " ^ presses

let case name input expectation : Table_test.case = { name; input; expectation }

let () =
  Table_test.run "choose_gift"
    [
      case "the list: three Downs to Vivillon, then A" (run list)
        "ok; Down Down Down A";
      case "the cursor does not move: no A" (run ~moves:false list)
        "error: the cursor did not reach item 4; nothing claimed; Down Down \
         Down";
      case "not the list (the main menu): no press" (run menu)
        "error: no active gift list: items white 0.14 0.00 0.00 0.18 0.13 \
         0.00; names 0.126 0.103 0.099 0.112 0.122 0.107; card header 0.22, \
         text box 0.01; no press";
    ]
