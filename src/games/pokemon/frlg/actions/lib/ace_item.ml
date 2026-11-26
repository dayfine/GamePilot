module M = Menu_input

type game_steps = {
  storage : Item_storage.game_steps;
  bag_count : string -> int option;
}

type order = { slug : string; name : string; withdraw : int }

let stack = 999
let bag_most = 999

let bag steps o =
  match steps.bag_count o.slug with
  | Some n -> n
  | None ->
      M.fail "bag_unread" ("the bag's count of " ^ o.name ^ " did not read")

let check_room steps ~log o =
  Item_storage.check steps.storage ~log o.name None;
  let held = bag steps o in
  if held + o.withdraw > bag_most then
    M.fail "ace_bag_full"
      (Printf.sprintf "the bag holds %d %s: %d more is over %d" held o.name
         o.withdraw bag_most);
  log (Printf.sprintf "Room: the bag holds %d %s." held o.name)

let check_stored steps ~log o =
  Item_storage.check steps.storage ~log o.name (Some stack)

let withdraw steps ~log o =
  let before = bag steps o in
  Item_storage.withdraw steps.storage ~log o.name o.withdraw;
  let after = bag steps o in
  if after <> before + o.withdraw then
    M.fail "ace_bag_count"
      (Printf.sprintf "the bag holds %d %s, not %d + %d" after o.name before
         o.withdraw);
  log (Printf.sprintf "Bag: %d %s, %d withdrawn." after o.name o.withdraw)

let screen_game_steps ~log =
  {
    storage = Item_storage.screen_game_steps ~log;
    bag_count = Bag_items.count ~log;
  }

let order options =
  match
    (Run_options.find options "item", Run_options.int options "withdraw")
  with
  | Some slug, Some withdraw -> (
      match Item_storage.item_name slug with
      | Some name -> Ok { slug; name; withdraw }
      | None -> Error ("the game names no item " ^ slug))
  | _ ->
      Error
        "frlg.ace needs its item and withdraw options (--options item=<slug> \
         --options withdraw=<n>)"

let with_order ~options f (_ : Pokemon_engine.Plan.event) (_ : Json_field.obj) =
  match order options with
  | Error e -> Error (Pokemon_engine.Failure.cause ~repeats:true "bad_args" e)
  | Ok o -> M.run (fun () -> f o)

let handlers ~log ~options =
  let steps () = screen_game_steps ~log in
  [
    ( "ace_check_room",
      with_order ~options (fun o -> check_room (steps ()) ~log o) );
    ( "ace_check_stored",
      with_order ~options (fun o -> check_stored (steps ()) ~log o) );
    ("ace_withdraw", with_order ~options (fun o -> withdraw (steps ()) ~log o));
  ]
