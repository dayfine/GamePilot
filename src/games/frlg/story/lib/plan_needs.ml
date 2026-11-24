module J = Grid_maps.Json_field
module P = Story.Plan
module A = Frlg_actions

type need =
  | Party_in_order of string list
  | Party_includes of { members : string list; slots : P.slot list }
  | Member of { species : string; for_ : string }
  | Knows_move of { move : string; for_ : string }
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string

(* The args naming a member the action uses, and those naming one it brings. *)
let brings action =
  match action with
  | "capture" -> [ "species" ]
  | "ingame_trade" -> [ "receive" ]
  | _ -> []

let item_users = [ "give_bag_item"; "use_item"; "duplicate_item" ]
let yen_per_coin = 20

type acc = {
  members : (string * string) list;
      (** needed, with the action; newest first *)
  brought : string list;
  money : (int * string) list;
  items : (string * string) list;  (** needed, one per use *)
  bought : (string * int) list;
  knows : (string * string) list;  (** field move, action; newest first *)
}

let empty =
  {
    members = [];
    brought = [];
    money = [];
    items = [];
    bought = [];
    knows = [];
  }

(* The game lets any member that knows Cut cut: some member must know it. *)
let field_move_users = A.Action_args.field_move_users

let field_move action acc =
  let move = List.assoc action field_move_users in
  if List.mem_assoc move acc.knows then acc
  else { acc with knows = (move, action) :: acc.knows }

let use_member action acc species =
  if List.mem species acc.brought || List.mem_assoc species acc.members then acc
  else { acc with members = (species, action) :: acc.members }

let use_item action acc item =
  match List.assoc_opt item acc.bought with
  | Some n when n > 0 ->
      { acc with bought = (item, n - 1) :: List.remove_assoc item acc.bought }
  | _ -> { acc with items = (item, action) :: acc.items }

let mart stocks ~where args acc =
  let t = A.Mart_plan.of_args stocks ~where args in
  let stock = Option.value (A.Mart_plan.stock stocks t.map) ~default:[] in
  let buys = A.Mart_plan.buys stock t in
  let cost =
    List.fold_left (fun s (b : A.Mart_plan.buy) -> s + b.cost) 0 buys
  in
  let add bought (l : A.Mart_plan.line) =
    let had = Option.value (List.assoc_opt l.line_item bought) ~default:0 in
    (l.line_item, had + l.quantity) :: List.remove_assoc l.line_item bought
  in
  {
    acc with
    money = (cost, "mart") :: acc.money;
    bought = List.fold_left add acc.bought t.lines;
  }

let use_members ~named action acc =
  List.fold_left
    (fun acc key ->
      if List.mem key (brings action) then acc
      else Option.fold ~none:acc ~some:(use_member action acc) (named key))
    acc A.Action_args.member_keys

let game_action stocks ~where action args acc =
  let named key = J.string_opt ~where key args in
  let acc =
    if List.mem_assoc action field_move_users then field_move action acc
    else use_members ~named action acc
  in
  let acc =
    if List.mem action item_users then
      Option.fold ~none:acc ~some:(use_item action acc) (named "item")
    else acc
  in
  let acc =
    match action with
    | "mart" -> mart stocks ~where args acc
    | "buy_coins" ->
        let coins = A.Game_corner.coins_of_args ~where args in
        { acc with money = (coins * yen_per_coin, "buy_coins") :: acc.money }
    | _ -> acc
  in
  let brought = List.filter_map named (brings action) in
  { acc with brought = brought @ acc.brought }

let event stocks acc (e : P.event) =
  match (e.kind, e.action) with
  | Game_action args, Some action ->
      game_action stocks ~where:(e.id ^ ": ") action args acc
  | _ -> acc

let party_needs before acc =
  let promised =
    match before with
    | Some { P.party = Some (P.Party_in_order l); _ } -> [ Party_in_order l ]
    | Some { P.party = Some (P.Party_includes { members; slots }); _ } ->
        [ Party_includes { members; slots } ]
    | _ -> []
  in
  promised
  @ List.rev_map (fun (species, for_) -> Member { species; for_ }) acc.members
  @ List.rev_map (fun (move, for_) -> Knows_move { move; for_ }) acc.knows

let money_needs before acc =
  let promised =
    match before with
    | Some { P.money = Some { min; max }; _ } -> [ Money_between { min; max } ]
    | _ -> []
  in
  let total = List.fold_left (fun s (n, _) -> s + n) 0 acc.money in
  let for_ = String.concat ", " (List.rev_map snd acc.money) in
  promised
  @ if total > 0 then [ Money_at_least { amount = total; for_ } ] else []

(* One more use of the item, the first use's action kept. *)
let count_use l (item, for_) =
  match List.assoc_opt item l with
  | Some (n, f) -> (item, (n + 1, f)) :: List.remove_assoc item l
  | None -> (item, (1, for_)) :: l

let item_needs before acc =
  let exactly (i : P.item) =
    Item_exactly { item = i.item; count = i.quantity }
  in
  let promised =
    Option.fold ~none:[]
      ~some:(fun (p : P.postconditions) -> List.map exactly p.items)
      before
  in
  let counted = List.fold_left count_use [] (List.rev acc.items) in
  promised
  @ List.rev_map
      (fun (item, (count, for_)) -> Item_at_least { item; count; for_ })
      counted

let needs stocks ~before (plan : P.t) =
  let acc = List.fold_left (event stocks) empty plan.checkpoint.events in
  let place =
    match plan.checkpoint.start with
    | Some (Grid { map; _ }) -> [ Place map ]
    | _ -> []
  in
  party_needs before acc @ money_needs before acc @ item_needs before acc
  @ place
