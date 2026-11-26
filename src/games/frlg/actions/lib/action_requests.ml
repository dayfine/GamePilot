module J = Json_field

type swap = By_species of string * int | Slots of int * int
type deposit = Members of string list | Holding_no_mail

type t =
  | Mart of Mart_plan.t
  | Use_item of { item : string; on : Action_args.member option }
  | Give_bag_item of { item : string; to_ : Action_args.member }
  | Party_swap of swap
  | Buy_coins of int
  | Redeem_prize_mon of int
  | Ingame_trade of { offer : string; receive : string option }
  | Spin_for_encounter of { max_batches : int }
  | Cut_tree of Grid_geometry.Direction.t
  | Verify_mail_glitch of Action_args.member
  | Pc_deposit of deposit
  | Pc_withdraw
  | Pick_up_item of string
  | Read_caught of { at_least : int option }

let default_spin_batches = 25
let holding_no_mail = "holding_no_mail"

let pc_deposit ~where args =
  match J.string_opt ~where "member" args with
  | Some _ when J.has "species" args ->
      J.fail "%sspecies and member: name the members or their role, not both."
        where
  | Some m when m = holding_no_mail -> Pc_deposit Holding_no_mail
  | Some m -> J.fail "%smember is %s, not %s." where m holding_no_mail
  | None ->
      Pc_deposit
        (Members (J.strings (where ^ "species") (J.field ~where "species" args)))

let use_item ~where args =
  let on =
    if J.has "species" args || J.has "target_slot" args then
      Some (Action_args.member ~where args)
    else None
  in
  Use_item { item = J.string ~where "item" args; on }

let give_bag_item ~where args =
  Give_bag_item
    { item = J.string ~where "item" args; to_ = Action_args.member ~where args }

let party_swap ~where args =
  let slot key = Action_args.slot ~where key args in
  match J.string_opt ~where "species" args with
  | Some species -> Party_swap (By_species (species, slot "target_slot"))
  | None -> Party_swap (Slots (slot "slot_a", slot "slot_b"))

let ingame_trade ~where args =
  Ingame_trade
    {
      offer = J.string ~where "species" args;
      receive = J.string_opt ~where "receive" args;
    }

let spin ~where args =
  match J.find "max_batches" args with
  | None -> Spin_for_encounter { max_batches = default_spin_batches }
  | Some _ ->
      Spin_for_encounter { max_batches = J.int ~where "max_batches" args }

(* At most the National Pokedex's 386. *)
let max_caught = 386

let read_caught ~where args =
  let at_least =
    if J.has "at_least" args then (
      let n = J.int ~where "at_least" args in
      if n < 0 || n > max_caught then
        J.fail "%sat_least is %d, not 0..%d" where n max_caught;
      Some n)
    else None
  in
  Read_caught { at_least }

let readers stocks =
  [
    ("mart", fun ~where args -> Mart (Mart_plan.of_args stocks ~where args));
    ("use_item", use_item);
    ("give_bag_item", give_bag_item);
    ("party_swap", party_swap);
    ("buy_coins", fun ~where a -> Buy_coins (Game_corner.coins_of_args ~where a));
    ( "redeem_prize_mon",
      fun ~where a -> Redeem_prize_mon (Game_corner.prize_slot_of_args ~where a)
    );
    ("ingame_trade", ingame_trade);
    ("spin_for_encounter", spin);
    ( "cut_tree",
      fun ~where a ->
        Cut_tree (Grid_maps.Grid_field.direction ~where "direction" a) );
    ( "verify_mail_glitch",
      fun ~where a -> Verify_mail_glitch (Action_args.member ~where a) );
    ("pc_deposit", pc_deposit);
    ("pc_withdraw", fun ~where:_ _ -> Pc_withdraw);
    ("pick_up_item", fun ~where a -> Pick_up_item (J.string ~where "item" a));
    ("read_caught", read_caught);
  ]

let names =
  [
    "mart";
    "use_item";
    "give_bag_item";
    "party_swap";
    "buy_coins";
    "redeem_prize_mon";
    "ingame_trade";
    "spin_for_encounter";
    "cut_tree";
    "verify_mail_glitch";
    "pc_deposit";
    "pc_withdraw";
    "pick_up_item";
    "read_caught";
  ]

let decode stocks name args =
  match List.assoc_opt name (readers stocks) with
  | Some read -> Action_args.decode ~action:name read args
  | None ->
      Error (Pokemon_engine.Failure.cause ~repeats:true "unknown_action" name)

let member_text = Action_args.member_to_string

let line_text (l : Mart_plan.line) =
  Printf.sprintf "%d %s" l.quantity l.line_item

let mart_text (p : Mart_plan.t) =
  let lines = String.concat ", " (List.map line_text p.lines) in
  let budget =
    Option.fold ~none:"" ~some:(Printf.sprintf ", budget $%d") p.budget
  in
  Printf.sprintf "mart %s: %s%s" p.map lines budget

let to_string = function
  | Mart p -> mart_text p
  | Use_item { item; on } ->
      "use " ^ item
      ^ Option.fold ~none:"" ~some:(fun m -> " on " ^ member_text m) on
  | Give_bag_item { item; to_ } -> "give " ^ item ^ " to " ^ member_text to_
  | Party_swap (By_species (s, n)) -> Printf.sprintf "swap %s to slot %d" s n
  | Party_swap (Slots (a, b)) -> Printf.sprintf "swap slots %d and %d" a b
  | Buy_coins n -> Printf.sprintf "buy %d coins" n
  | Redeem_prize_mon n -> Printf.sprintf "redeem prize row %d" n
  | Ingame_trade { offer; receive } ->
      "trade " ^ offer ^ Option.fold ~none:"" ~some:(( ^ ) " for ") receive
  | Spin_for_encounter { max_batches } ->
      Printf.sprintf "spin for an encounter, %d batches at most" max_batches
  | Cut_tree d -> "cut the tree to the " ^ Grid_geometry.Direction.name d
  | Verify_mail_glitch m -> "verify the mail glitch on " ^ member_text m
  | Pc_deposit (Members l) -> "deposit " ^ String.concat ", " l ^ " at the PC"
  | Pc_deposit Holding_no_mail -> "deposit the member holding no Mail at the PC"
  | Pc_withdraw -> "withdraw the first Pokemon in the box at the PC"
  | Pick_up_item item -> "pick up " ^ item
  | Read_caught { at_least } ->
      "read the species caught"
      ^ Option.fold ~none:"" ~some:(Printf.sprintf ", at least %d") at_least
