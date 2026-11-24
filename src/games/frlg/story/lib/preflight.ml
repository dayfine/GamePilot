module J = Grid_maps.Json_field
module P = Story.Plan
module A = Frlg_actions

type need =
  | Party_in_order of string list
  | Party_includes of string list
  | Member of { species : string; for_ : string }
  | Money_at_least of { amount : int; for_ : string }
  | Money_between of { min : int; max : int }
  | Item_at_least of { item : string; count : int; for_ : string }
  | Item_exactly of { item : string; count : int }
  | Place of string

(* The args naming a member the action uses, and those naming one it brings. *)
let member_keys =
  [ "species"; "sweeper"; "knock_off_species"; "recycle_species" ]

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
}

let empty = { members = []; brought = []; money = []; items = []; bought = [] }

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

let game_action stocks ~where action args acc =
  let named key = J.string_opt ~where key args in
  let acc =
    List.fold_left
      (fun acc key ->
        if List.mem key (brings action) then acc
        else Option.fold ~none:acc ~some:(use_member action acc) (named key))
      acc member_keys
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
    | Some { P.party = Some (P.Party_includes l); _ } -> [ Party_includes l ]
    | _ -> []
  in
  promised
  @ List.rev_map (fun (species, for_) -> Member { species; for_ }) acc.members

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

type read = {
  observed : Story.Postcondition_check.observed;
  place : Frlg_readers.Start_frame.difference option;
}

type verdict = Ok | Mismatch | Not_read
type row = { need : string; read : string; verdict : verdict }

let of_bool b = if b then Ok else Mismatch
let species_list l = String.concat ", " l

let party_text = function
  | None -> "not read"
  | Some members -> species_list (List.map (Option.value ~default:"?") members)

let with_party (read : read) need test =
  match read.observed.party with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some members ->
      {
        need;
        read = party_text (Some members);
        verdict = of_bool (test members);
      }

let has members species = List.mem (Some species) members

let with_money (read : read) need test =
  match read.observed.money with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some m ->
      { need; read = Printf.sprintf "¥%d" m; verdict = of_bool (test m) }

let with_item (read : read) item need test =
  match List.assoc_opt item read.observed.items with
  | None -> { need; read = "not read"; verdict = Not_read }
  | Some n ->
      {
        need;
        read = Printf.sprintf "%s x%d" item n;
        verdict = of_bool (test n);
      }

let place_row read map =
  let need = "at the start, " ^ map in
  match read.place with
  | None ->
      { need; read = "no kept start frame to compare"; verdict = Not_read }
  | Some d ->
      let module F = Frlg_readers.Start_frame in
      {
        need;
        read = F.difference_to_string d;
        verdict = of_bool (F.same_place d);
      }

let row read = function
  | Party_in_order l ->
      with_party read
        ("party " ^ species_list l)
        (fun m -> m = List.map Option.some l)
  | Party_includes l ->
      with_party read
        ("party includes " ^ species_list l)
        (fun m -> List.for_all (has m) l)
  | Member { species; for_ } ->
      with_party read (Printf.sprintf "%s in the party (%s)" species for_)
        (fun m -> has m species)
  | Money_at_least { amount; for_ } ->
      with_money read (Printf.sprintf "money at least ¥%d (%s)" amount for_)
        (fun m -> m >= amount)
  | Money_between { min; max } ->
      with_money read (Printf.sprintf "money ¥%d..¥%d" min max) (fun m ->
          m >= min && m <= max)
  | Item_at_least { item; count; for_ } ->
      with_item read item
        (Printf.sprintf "%s at least x%d (%s)" item count for_) (fun n ->
          n >= count)
  | Item_exactly { item; count } ->
      with_item read item (Printf.sprintf "%s x%d" item count) (fun n ->
          n = count)
  | Place map -> place_row read map

let compare needs read = List.map (row read) needs

let room need read =
  let need_text, read_text, ok = Party_room.report need read.observed.party in
  let verdict =
    match ok with Some true -> Ok | Some false -> Mismatch | None -> Not_read
  in
  { need = need_text; read = read_text; verdict }

let passed rows = List.for_all (fun r -> r.verdict = Ok) rows

let verdict_text = function
  | Ok -> "ok"
  | Mismatch -> "MISMATCH"
  | Not_read -> "NOT READ"

let table rows =
  let width f =
    List.fold_left (fun w r -> max w (String.length (f r))) 4 rows
  in
  let wn = width (fun r -> r.need) and wr = width (fun r -> r.read) in
  let line a b c = Printf.sprintf "%-*s  %-*s  %s" wn a wr b c in
  String.concat "\n"
    (line "NEED" "READ" "VERDICT"
    :: List.map (fun r -> line r.need r.read (verdict_text r.verdict)) rows)

let to_read needs : P.postconditions =
  let party =
    List.exists
      (function
        | Party_in_order _ | Party_includes _ | Member _ -> true | _ -> false)
      needs
  and money =
    List.exists
      (function Money_at_least _ | Money_between _ -> true | _ -> false)
      needs
  in
  let items =
    List.sort_uniq Stdlib.compare
      (List.filter_map
         (function
           | Item_at_least { item; _ } | Item_exactly { item; _ } -> Some item
           | _ -> None)
         needs)
  in
  {
    position = None;
    party = (if party then Some (P.Party_includes []) else None);
    items = List.map (fun item -> { P.item; quantity = 0 }) items;
    coins = None;
    money = (if money then Some { P.min = 0; max = 0 } else None);
    flags = [];
    knows = [];
    levels = [];
  }
