module P = Pokemon_engine.Plan
module Postconditions = Pokemon_engine.Postconditions
module A = Frlg_actions
open Need

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

let use_action_member action acc = function
  | A.Action_args.Species s -> use_member action acc s
  | A.Action_args.Slot _ -> acc

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

let mart stocks (t : A.Mart_plan.t) acc =
  let stock = Option.value (A.Mart_plan.stock stocks t.map) ~default:[] in
  let buys = A.Mart_plan.buys stock t in
  let cost =
    List.fold_left (fun s (b : A.Mart_plan.buy) -> s + b.cost) 0 buys
  in
  let lines =
    List.map (fun (l : A.Mart_plan.line) -> (l.line_item, l.quantity)) t.lines
  in
  List.fold_left gain { acc with money = (cost, "mart") :: acc.money } lines

let of_request stocks action acc : A.Action_requests.t -> acc = function
  | Mart t -> mart stocks t acc
  | Use_item { item; on } ->
      let acc = Option.fold ~none:acc ~some:(use_action_member action acc) on in
      use_item action acc item
  | Give_bag_item { item; to_ } ->
      use_item action (use_action_member action acc to_) item
  | Party_swap (By_species (s, _)) -> use_member action acc s
  | Party_swap (Slots _) -> acc
  | Buy_coins coins ->
      { acc with money = (coins * yen_per_coin, action) :: acc.money }
  | Ingame_trade { offer; receive } ->
      let acc = use_member action acc offer in
      { acc with brought = Option.to_list receive @ acc.brought }
  | Cut_tree _ | Surf -> field_move action (use_badge action acc)
  | Verify_mail_glitch member -> use_action_member action acc member
  | Pc_deposit Holding_no_mail ->
      let first = Option.value acc.without_mail ~default:action in
      { acc with without_mail = Some first }
  | Pc_deposit (Members species) ->
      List.fold_left (deposit action)
        (List.fold_left (use_member action) acc species)
        species
  | Pick_up_item item -> gain acc (item, 1)
  | Redeem_prize_mon _ | Spin_for_encounter _ | Pc_withdraw | Read_caught _ ->
      acc

(* One ball at least: the plan's, a Poke Ball when it names none. *)
let of_capture action acc (plan : A.Capture_plan.t) =
  let acc = use_item action acc plan.ball in
  match plan.target with
  | Species s -> { acc with brought = s :: acc.brought }
  | Uncaught _ -> acc

(* duplicate_item takes nothing from the bag: it copies the item slot 1 holds,
   given before it (tt-01's picked-up Rare Candy was counted twice, console B
   2026-11-24). A round gives one Retro Mail and starts only with two on the row
   (Item_duplication.min_mail): count + 1 in the bag at the start. *)
let of_duplicate action acc (member, (plan : A.Item_duplication.plan)) =
  let acc = use_action_member action acc member in
  List.fold_left (use_item action) acc
    (List.init
       (plan.rounds + A.Item_duplication.min_mail - 1)
       (fun _ -> "retro-mail"))

(* The Rare Candy actions need one candy at least; how many more a
   [candy_level] eats depends on the member's level. *)
let of_candy action acc member =
  use_item action (use_action_member action acc member) "rare-candy"

let decode_error ~where (cause : Pokemon_engine.Failure.cause) =
  where ^ cause.detail

let decode_duplicate ~where args =
  ( A.Action_args.member ~where args,
    A.Mail_glitch_use.duplication_plan ~options:Run_options.none ~where args )

let game_action stocks ~where action args acc =
  let map f r = Result.map f (Result.map_error (decode_error ~where) r) in
  match action with
  | _ when List.mem action A.Action_requests.names ->
      map
        (of_request stocks action acc)
        (A.Action_requests.decode stocks action args)
  | _ when List.mem_assoc action field_move_users ->
      Ok (field_move action (use_badge action acc))
  | "capture" | "wild_rng" | "static_rng" ->
      map (of_capture action acc) (A.Capture_plan.decode args)
  | "gift_rng" ->
      let decode ~where a = Json_field.string ~where "species" a in
      map
        (fun s -> { acc with brought = s :: acc.brought })
        (A.Action_args.decode ~action decode args)
  | "duplicate_item" ->
      map (of_duplicate action acc)
        (A.Action_args.decode ~action decode_duplicate args)
  | "use_rare_candy" ->
      map
        (fun (u : A.Candy_plan.use) -> of_candy action acc u.member)
        (A.Candy_plan.decode_use args)
  | "candy_level" ->
      map
        (fun (g : A.Candy_plan.goal) -> of_candy action acc g.use.member)
        (A.Candy_plan.decode_goal args)
  | _ ->
      map
        (List.fold_left (use_member action) acc)
        (A.Action_args.decode ~action A.Action_args.named_species args)

let event stocks acc (e : P.event) =
  match (e.kind, e.way) with
  | Named_action args, Some action ->
      game_action stocks ~where:(e.id ^ ": ") action args acc
  | _ -> Ok acc

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
  let step acc e = Result.bind acc (fun acc -> event stocks acc e) in
  Result.map
    (fun acc ->
      let place =
        match plan.checkpoint.start with
        | Some (Grid { map; _ }) -> [ Place map ]
        | Some (Anywhere place_class) -> [ Anywhere_start place_class ]
        | _ -> []
      in
      party_needs before acc @ money_needs before acc @ item_needs before acc
      @ place)
    (List.fold_left step (Ok empty) plan.checkpoint.events)
