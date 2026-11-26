(* Ace_item on a fake item storage (a short list: no scrolling) and a fake
   bag: room before the trigger, the item x999 after, and the withdrawal
   counted in the bag. Item_storage's own walk, a full storage among it, is
   test_item_storage's. *)

open Frlg_actions
module I = Ace_item

type fake = {
  mutable stock : (string * int) list;
  mutable bag : int;
  mutable cursor : int;
  mutable menu : [ `List | `Submenu | `Quantity of int ];
  lost : int;  (** balls the bag does not show after a withdrawal *)
}

let withdraw f q =
  let name, have = List.nth f.stock f.cursor in
  f.stock <-
    List.mapi (fun i s -> if i = f.cursor then (name, have - q) else s) f.stock;
  f.bag <- f.bag + q - f.lost;
  f.menu <- `List

let press f (b : Wire.button) =
  let have = snd (List.nth f.stock f.cursor) in
  match (f.menu, b) with
  | `List, Up -> f.cursor <- max 0 (f.cursor - 1)
  | `List, Down -> f.cursor <- f.cursor + 1
  | `List, A -> f.menu <- `Submenu
  | `Submenu, A -> f.menu <- `Quantity 1
  | `Quantity q, A -> withdraw f q
  | `Quantity q, Up -> f.menu <- `Quantity (if q = have then 1 else q + 1)
  | `Quantity q, Down -> f.menu <- `Quantity (if q = 1 then have else q - 1)
  | `Quantity q, Right -> f.menu <- `Quantity (min have (q + 10))
  | `Quantity q, Left -> f.menu <- `Quantity (max 1 (q - 10))
  | _ -> ()

let storage f : Item_storage.game_steps =
  {
    open_withdraw =
      (fun () ->
        f.cursor <- 0;
        f.menu <- `List);
    read_row =
      (fun i name ->
        match List.nth_opt f.stock i with
        | Some (n, count) -> Some (Item { named = n = name; count })
        | None when i = List.length f.stock -> Some Cancel
        | None -> None);
    cursor_row = (fun () -> Some f.cursor);
    press = press f;
    await_quantity =
      (fun () -> match f.menu with `Quantity _ -> true | _ -> false);
    read_quantity =
      (fun () -> match f.menu with `Quantity q -> Some q | _ -> None);
    close = (fun () -> ());
  }

let steps f : I.game_steps =
  { storage = storage f; bag_count = (fun _ -> Some f.bag) }

let make ?(bag = 0) ?(lost = 0) stock =
  { stock; bag; cursor = 0; menu = `List; lost }

let order n : I.order =
  { slug = "master-ball"; name = "MASTER BALL"; withdraw = n }

let outcome f run =
  match run (steps f) with
  | () -> Printf.sprintf "ok; bag %d" f.bag
  | exception Menu_input.Action_failed c -> c.code

let filler n = List.init n (fun i -> (Printf.sprintf "ITEM%d" i, 1))
let master n = ("MASTER BALL", n)

let room ?bag stock n =
  outcome (make ?bag stock) (fun s -> I.check_room s ~log:ignore (order n))

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "ace_item"
    [
      case "room: one stack stored, an empty bag"
        (fun () -> room [ master 1 ] 50)
        "ok; bag 0";
      case "room: five stacks stored" (fun () -> room (filler 5) 50) "ok; bag 0";
      case "room: 949 in the bag and 50 more"
        (fun () -> room ~bag:949 [] 50)
        "ok; bag 949";
      case "no room: 950 in the bag and 50 more"
        (fun () -> room ~bag:950 [] 50)
        "ace_bag_full";
      case "stored: a stack of 999"
        (fun () ->
          outcome
            (make [ master 1; master 999 ])
            (fun s -> I.check_stored s ~log:ignore (order 50)))
        "ok; bag 0";
      case "not stored: no stack of 999"
        (fun () ->
          outcome
            (make [ master 1 ])
            (fun s -> I.check_stored s ~log:ignore (order 50)))
        "item_storage_missing";
      case "50 withdrawn: the bag from 1 to 51"
        (fun () ->
          outcome
            (make ~bag:1 [ master 999 ])
            (fun s -> I.withdraw s ~log:ignore (order 50)))
        "ok; bag 51";
      case "the bag short after the withdrawal"
        (fun () ->
          outcome
            (make ~lost:1 [ master 999 ])
            (fun s -> I.withdraw s ~log:ignore (order 50)))
        "ace_bag_count";
    ]
