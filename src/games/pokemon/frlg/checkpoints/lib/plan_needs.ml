module J = Json_field
module P = Pokemon_engine.Plan
module Postconditions = Pokemon_engine.Postconditions
module A = Frlg_actions
open Need

(* The args naming a member the action uses, and those naming one it brings. *)
let brings action =
  match action with
  | "capture" | "wild_rng" -> [ "species" ]
  | "ingame_trade" -> [ "receive" ]
  | _ -> []

(* duplicate_item takes nothing from the bag: it copies the item slot 1 holds,
   given before it (tt-01's picked-up Rare Candy was counted twice, console B
   2026-11-24). *)
let item_users = [ "give_bag_item"; "use_item" ]

(* The Rare Candy actions need one candy at least; how many more a
   [candy_level] eats depends on the member's level. *)
let candy_users = [ "use_rare_candy"; "candy_level" ]
let yen_per_coin = 20

type acc = {
  members : (string * string) list;
      (** needed, with the action; newest first *)
  brought : string list;
  money : (int * string) list;
  items : (string * string) list;  (** needed, one per use *)
  bought : (string * int) list;  (** bought or picked up, not yet used *)
  knows : (string * string) list;  (** field move, action; newest first *)
  badges : (string * string) list;  (** badge, action; newest first *)
  deposits : (string * string) list;
      (** the save's members stored, with the action; newest first *)
  without_mail : string option;
      (** the first action storing the member holding no Mail *)
}

let empty =
  {
    members = [];
    brought = [];
    money = [];
    items = [];
    bought = [];
    knows = [];
    badges = [];
    deposits = [];
    without_mail = None;
  }

(* Any member that knows Cut cuts, and the first that knows Fly flies: some
   member must know the move. *)
let field_move_users = A.Action_args.field_move_users

let field_move action acc =
  let move = List.assoc action field_move_users in
  if List.mem_assoc move acc.knows then acc
  else { acc with knows = (move, action) :: acc.knows }

let use_badge action acc =
  match A.Action_args.badge_needed action with
  | Some badge when not (List.mem_assoc badge acc.badges) ->
      { acc with badges = (badge, action) :: acc.badges }
  | _ -> acc

let use_member action acc species =
  if List.mem species acc.brought || List.mem_assoc species acc.members then acc
  else { acc with members = (species, action) :: acc.members }

(* A member the save holds, stored: it must hold no Mail. *)
let deposit action acc species =
  if List.mem species acc.brought || List.mem_assoc species acc.deposits then
    acc
  else { acc with deposits = (species, action) :: acc.deposits }

let use_item action acc item =
  match List.assoc_opt item acc.bought with
  | Some n when n > 0 ->
      { acc with bought = (item, n - 1) :: List.remove_assoc item acc.bought }
  | _ -> { acc with items = (item, action) :: acc.items }

let gain acc (item, quantity) =
  let had = Option.value (List.assoc_opt item acc.bought) ~default:0 in
  {
    acc with
    bought = (item, had + quantity) :: List.remove_assoc item acc.bought;
  }

let mart stocks ~where args acc =
  let t = A.Mart_plan.of_args stocks ~where args in
  let stock = Option.value (A.Mart_plan.stock stocks t.map) ~default:[] in
  let buys = A.Mart_plan.buys stock t in
  let cost =
    List.fold_left (fun s (b : A.Mart_plan.buy) -> s + b.cost) 0 buys
  in
  let lines =
    List.map (fun (l : A.Mart_plan.line) -> (l.line_item, l.quantity)) t.lines
  in
  List.fold_left gain { acc with money = (cost, "mart") :: acc.money } lines

let use_members ~named action acc =
  List.fold_left
    (fun acc key ->
      if List.mem key (brings action) then acc
      else Option.fold ~none:acc ~some:(use_member action acc) (named key))
    acc A.Action_args.member_keys

let game_action stocks ~where action args acc =
  let named key = J.string_opt ~where key args in
  let acc = use_badge action acc in
  let acc =
    if List.mem_assoc action field_move_users then field_move action acc
    else if action = "pc_deposit" && J.has "member" args then
      let first = Option.value acc.without_mail ~default:action in
      { acc with without_mail = Some first }
    else if action = "pc_deposit" then
      let species = A.Action_args.deposited_species ~where args in
      List.fold_left (deposit action)
        (List.fold_left (use_member action) acc species)
        species
    else use_members ~named action acc
  in
  let acc =
    if List.mem action item_users then
      Option.fold ~none:acc ~some:(use_item action acc) (named "item")
    else if List.mem action candy_users then use_item action acc "rare-candy"
    else if action = "duplicate_item" then
      (* A round gives one Retro Mail and starts only with two on the row
         (Item_duplication.min_mail): count + 1 in the bag at the start. *)
      let rounds = J.int ~where "count" args in
      List.fold_left (use_item action) acc
        (List.init
           (rounds + A.Item_duplication.min_mail - 1)
           (fun _ -> "retro-mail"))
    else if action = "capture" || action = "wild_rng" then
      (* One ball at least: the plan's, a Poke Ball when it names none. *)
      use_item action acc
        (Option.value (named "ball") ~default:A.Capture_plan.default_ball)
    else if action = "pick_up_item" then
      Option.fold ~none:acc
        ~some:(fun item -> gain acc (item, 1))
        (named "item")
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
  match (e.kind, e.way) with
  | Named_action args, Some action ->
      game_action stocks ~where:(e.id ^ ": ") action args acc
  | _ -> acc

let party_needs before acc =
  let promised =
    match (before : Postconditions.t option) with
    | Some { party = Some (Party_in_order l); _ } -> [ Party_in_order l ]
    | Some { party = Some (Party_includes { members; slots }); _ } ->
        [ Party_includes { members; slots } ]
    | _ -> []
  in
  promised
  @ List.rev_map (fun (species, for_) -> Member { species; for_ }) acc.members
  @ List.rev_map (fun (species, for_) -> No_mail { species; for_ }) acc.deposits
  @ Option.fold ~none:[]
      ~some:(fun for_ -> [ Holding_no_mail { for_ } ])
      acc.without_mail
  @ List.rev_map (fun (move, for_) -> Knows_move { move; for_ }) acc.knows
  @ List.rev_map (fun (badge, for_) -> Badge { badge; for_ }) acc.badges

let money_needs before acc =
  let promised =
    match (before : Postconditions.t option) with
    | Some { money = Some (Range { min; max }); _ } ->
        [ Money_between { min; max } ]
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

(* A count promised before: an exact count or a floor carries over; a gain
   says nothing of the save's count. *)
let promised_count ({ bag_item = item; count } : Postconditions.bag_count) =
  match count with
  | Engine_postcondition.Count.Exactly count ->
      Some (Item_exactly { item; count })
  | Engine_postcondition.Count.At_least count ->
      Some (Item_at_least { item; count; for_ = "promised before" })
  | Engine_postcondition.Count.Gained _ -> None

let item_needs before acc =
  let promised =
    Option.fold ~none:[]
      ~some:(fun (p : Postconditions.t) ->
        List.filter_map promised_count p.items)
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
    | Some (Anywhere place_class) -> [ Anywhere_start place_class ]
    | _ -> []
  in
  party_needs before acc @ money_needs before acc @ item_needs before acc
  @ place
