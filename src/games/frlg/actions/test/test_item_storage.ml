(* Item_storage on a fake WITHDRAW ITEM list: stored stacks then CANCEL,
   six rows shown and scrolled as list_menu.c scrolls them (the cursor stops
   on the fourth row going down until the list's end shows), and the
   quantity box as menu_helpers.c moves it. *)

open Frlg_actions
module S = Item_storage

type fake = {
  stock : (string * int) array;
  mutable cursor : int;  (** list row *)
  mutable scroll : int;  (** list row on the top shown row *)
  mutable menu : [ `List | `Submenu | `Quantity of int | `Done ];
  mutable trace : string list;
  mutable withdrawn : int;
}

let rows f = Array.length f.stock + 1
let shown f = min 6 (rows f)
let note f s = f.trace <- s :: f.trace

let move f d =
  let c = max 0 (min (rows f - 1) (f.cursor + d)) in
  f.cursor <- c;
  if c < f.scroll then f.scroll <- c
  else if c - f.scroll > 3 && f.scroll + shown f < rows f then
    f.scroll <- min (c - 3) (rows f - shown f)

let quantity f q (b : Wire.button) =
  let have = snd f.stock.(f.cursor) in
  match b with
  | Up -> if q + 1 > have then 1 else q + 1
  | Down -> if q - 1 <= 0 then have else q - 1
  | Right -> min have (q + 10)
  | Left -> max 1 (q - 10)
  | _ -> q

let press f (b : Wire.button) =
  note f (Wire.string_of_button b);
  match (f.menu, b) with
  | `List, (Up | Down) -> move f (if b = Up then -1 else 1)
  | `List, A when f.cursor < Array.length f.stock -> f.menu <- `Submenu
  | `Submenu, A ->
      if snd f.stock.(f.cursor) = 1 then (
        f.withdrawn <- 1;
        f.menu <- `Done)
      else f.menu <- `Quantity 1
  | `Quantity q, A ->
      f.withdrawn <- q;
      f.menu <- `Done
  | `Quantity q, _ -> f.menu <- `Quantity (quantity f q b)
  | `Done, A -> f.menu <- `List
  | _ -> ()

let row_text f k name : S.row option =
  if k = Array.length f.stock then Some Cancel
  else
    let n, count = f.stock.(k) in
    Some (Item { named = n = name; count })

let steps f : S.game_steps =
  {
    open_withdraw = (fun () -> note f "open");
    read_row = (fun i name -> row_text f (f.scroll + i) name);
    cursor_row = (fun () -> Some (f.cursor - f.scroll));
    press = press f;
    await_quantity =
      (fun () -> match f.menu with `Quantity _ -> true | _ -> false);
    read_quantity =
      (fun () -> match f.menu with `Quantity q -> Some q | _ -> None);
    close = (fun () -> note f "close");
  }

let make stock =
  {
    stock = Array.of_list stock;
    cursor = 0;
    scroll = 0;
    menu = `List;
    trace = [];
    withdrawn = 0;
  }

let outcome f run =
  match run (steps f) with
  | () -> "ok"
  | exception Menu_input.Action_failed c -> c.code

let scanned stock () =
  let f = make stock in
  let s = S.scan (steps f) "MASTER BALL" in
  Printf.sprintf "%d items; stacks %s; cursor %d" s.items
    (String.concat ","
       (List.map (fun (k, c) -> Printf.sprintf "%d:x%d" k c) s.stacks))
    f.cursor

let withdrawn stock count () =
  let f = make stock in
  let o = outcome f (fun st -> S.withdraw st ~log:ignore "MASTER BALL" count) in
  Printf.sprintf "%s: withdrew %d; %d presses" o f.withdrawn
    (List.length f.trace - 2)

let checked stock count () =
  let f = make stock in
  outcome f (fun st -> S.check st ~log:ignore "MASTER BALL" count)

let filler n = List.init n (fun i -> (Printf.sprintf "ITEM%d" i, 1))
let master = ("MASTER BALL", 999)

let presses ~now ~target ~stack =
  let rec go now n acc =
    match S.quantity_press ~now ~target ~stack with
    | None ->
        Printf.sprintf "%d presses: %s" n (String.concat " " (List.rev acc))
    | Some b ->
        let next =
          match b with
          | Up -> if now + 1 > stack then 1 else now + 1
          | Down -> if now - 1 <= 0 then stack else now - 1
          | Right -> min stack (now + 10)
          | Left -> max 1 (now - 10)
          | _ -> now
        in
        go next (n + 1) (Wire.string_of_button b :: acc)
  in
  go now 0 []

let case name input expectation : Table_test.case = { name; input; expectation }

let cases =
  [
    case "two items and CANCEL"
      (scanned [ ("POTION", 1); master ])
      "2 items; stacks 1:x999; cursor 0";
    case "eight items: the list scrolled to CANCEL"
      (scanned (filler 7 @ [ master ]))
      "8 items; stacks 7:x999; cursor 6";
    case "29 items: the code's slot free"
      (scanned (filler 28 @ [ master ]))
      "29 items; stacks 28:x999; cursor 27";
    case "full storage refused" (checked (filler 30) None) "item_storage_full";
    case "29 items pass" (checked (filler 29) None) "ok";
    case "x999 found" (checked [ ("POTION", 1); master ] (Some 999)) "ok";
    case "no x999: missing"
      (checked [ ("MASTER BALL", 3) ] (Some 999))
      "item_storage_missing";
    case "50 of 999"
      (withdrawn [ ("POTION", 1); master ] 50)
      "ok: withdrew 50; 18 presses";
    case "999 of 999: DOWN wraps to the stack"
      (withdrawn [ ("POTION", 1); master ] 999)
      "ok: withdrew 999; 6 presses";
    case "a stack of one: no quantity box"
      (withdrawn [ ("MASTER BALL", 1) ] 1)
      "ok: withdrew 1; 3 presses";
    case "more than stored"
      (withdrawn [ master ] 1000)
      "item_storage_missing: withdrew 0; -1 presses";
    case "quantity 1 to 300 of 999"
      (fun () -> presses ~now:1 ~target:300 ~stack:999)
      "38 presses: Right Right Right Right Right Right Right Right Right Right \
       Right Right Right Right Right Right Right Right Right Right Right Right \
       Right Right Right Right Right Right Right Up Up Up Up Up Up Up Up Up";
    case "quantity 1 to 999"
      (fun () -> presses ~now:1 ~target:999 ~stack:999)
      "1 presses: Down";
    case "quantity 12 to 8"
      (fun () -> presses ~now:12 ~target:8 ~stack:999)
      "4 presses: Down Down Down Down";
  ]

let () = Table_test.run "item_storage" cases
