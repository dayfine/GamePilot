module R = Action_requests

type context = {
  log : string -> unit;
  party : Party_roster.t ref;
  facing : unit -> Grid_geometry.Direction.t option;
  stocks : unit -> (Mart_plan.stocks, string) result;
}

let resolve ctx member =
  match Party_roster.resolve !(ctx.party) member with
  | Ok slot -> slot
  | Error cause -> raise (Menu_input.Action_failed cause)

let mart ctx (plan : Mart_plan.t) =
  let stock =
    Result.bind (ctx.stocks ()) (fun s ->
        Option.to_result
          ~none:(plan.map ^ " has no stock")
          (Mart_plan.stock s plan.map))
  in
  match stock with
  | Ok stock -> Mart.run ~log:ctx.log stock plan
  | Error e -> Menu_input.fail ~repeats:true "no_mart_stock" e

let swap ctx (swap : R.swap) =
  let a, b =
    match swap with
    | By_species (s, target) -> (resolve ctx (Species s), target)
    | Slots (a, b) -> (a, b)
  in
  if a <> b then (
    Party_actions.swap ~log:ctx.log a b;
    ctx.party := Party_roster.swap !(ctx.party) a b)

let trade ctx offer receive =
  let party = !(ctx.party) in
  match (Party_roster.slot_of party offer, receive) with
  | None, Some r when Party_roster.slot_of party r <> None ->
      ctx.log ("Trade: " ^ r ^ " is in the party already; skipped.")
  | _ ->
      let slot = resolve ctx (Species offer) in
      Ingame_trade.trade ~log:ctx.log ~slot;
      ctx.party :=
        Party_roster.replace party ~slot (Option.value receive ~default:"?")

let read_caught ~log at_least =
  match (Trainer_card_caught.read ~log, at_least) with
  | None, _ -> Menu_input.fail "caught_unread" "the Pokedex count did not read"
  | Some n, Some least when n < least ->
      Menu_input.fail "caught_short"
        (Printf.sprintf "%d species caught, not at least %d" n least)
  | Some _, _ -> ()

(* The species of the first member whose mark is not Mail, by the party as
   read. *)
let species_in ctx i =
  match List.nth_opt (Party_roster.to_list !(ctx.party)) i with
  | Some species -> species
  | None ->
      Menu_input.fail "not_in_party"
        (Printf.sprintf "slot %d is not in the party as read" (i + 1))

let without_mail ctx =
  let marks = Mail_glitch_use.read_marks ~log:ctx.log in
  match List.find_index (fun m -> m <> Frlg_readers.Party_menu.Mail) marks with
  | None -> Menu_input.fail ~repeats:true "no_member" "every member holds Mail"
  | Some i -> species_in ctx i

let deposited ctx : R.deposit -> string list = function
  | Members species -> species
  | Holding_no_mail -> [ without_mail ctx ]

let facing ctx =
  Option.value (ctx.facing ()) ~default:Grid_geometry.Direction.North

let body ctx (request : R.t) () =
  let log = ctx.log in
  match request with
  | Mart plan -> mart ctx plan
  | Use_item { item; on } ->
      Party_actions.use ~log ~item ~slot:(Option.map (resolve ctx) on)
  | Give_bag_item { item; to_ } ->
      Party_actions.give ~log ~item ~slot:(resolve ctx to_)
  | Party_swap s -> swap ctx s
  | Buy_coins n -> Game_corner.buy_coins ~log n
  | Redeem_prize_mon n ->
      Game_corner.redeem_prize_mon ~log n;
      ctx.party :=
        Party_roster.add !(ctx.party) (List.nth Game_corner.fire_red_prizes n)
  | Ingame_trade { offer; receive } -> trade ctx offer receive
  | Spin_for_encounter { max_batches } ->
      Spin_for_encounter.spin ~log ~facing:(facing ctx) ~max_batches
  | Cut_tree d -> Cut_tree.cut ~log d
  | Pc_deposit deposit ->
      let species = deposited ctx deposit in
      Pc_deposit.deposit ~log species;
      ctx.party := List.fold_left Party_roster.remove !(ctx.party) species
  | Pc_withdraw ->
      let species = Pc_withdraw.withdraw ~log in
      ctx.party := Party_roster.add !(ctx.party) species
  | Verify_mail_glitch member ->
      Party_actions.verify_mail_glitch ~log
        ~who:(Action_args.member_to_string member)
        ~slot:(resolve ctx member)
  | Pick_up_item _ -> Menu_input.raise_error (Talk.pick_up ~log ())
  | Read_caught { at_least } -> read_caught ~log at_least

let perform ctx request = Menu_input.run (body ctx request)

let handler ctx name (_ : Pokemon_engine.Plan.event) args =
  match (ctx.stocks (), name) with
  | Error e, "mart" ->
      Error (Pokemon_engine.Failure.cause ~repeats:true "no_mart_stock" e)
  | stocks, _ ->
      let stocks = Result.value stocks ~default:Mart_plan.empty in
      Result.bind (R.decode stocks name args) (perform ctx)

let handlers ctx =
  List.map (fun name -> (name, handler ctx name)) R.names
  @ Mail_glitch_use.handlers ~log:ctx.log ~party:ctx.party
  @ Candy_actions.handlers ~log:ctx.log ~party:ctx.party
  @ Ace_mail.handlers ~log:ctx.log ~party:ctx.party
  @ Box_rename.handlers ~log:ctx.log
  @ Ace_trigger.handlers ~log:ctx.log
  @ Item_storage.handlers ~log:ctx.log
