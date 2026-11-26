module J = Json_field

type stock_item = { item : string; price : int }
type stocks = (string * stock_item list) list

let empty = []
let asset = "src/games/frlg/assets/kanto_mart_stocks.json"
let source = "kanto_mart_stocks.json: "

let stock_item ~where obj =
  { item = J.string ~where "item" obj; price = J.int ~where "price" obj }

let mart ~where obj =
  (J.string ~where "map" obj, J.records ~where "stock" obj stock_item)

let parse json =
  match J.records ~where:source "marts" (J.as_object source json) mart with
  | stocks -> Ok stocks
  | exception J.Invalid e -> Error e

let read () =
  match Repo_io.Repo_files.locate asset with
  | None -> Error (asset ^ " not found from the working directory")
  | Some path -> (
      match Yojson.Safe.from_file path with
      | json -> parse json
      | exception Yojson.Json_error e -> Error (asset ^ ": " ^ e))

let loaded = lazy (read ())
let load () = Lazy.force loaded
let stock stocks map = List.assoc_opt map stocks

type line = { line_item : string; quantity : int }
type t = { map : string; lines : line list; budget : int option }

let max_quantity = 99

let line stock ~where obj =
  let line_item = J.string ~where "item" obj in
  let quantity = J.int ~where "quantity" obj in
  if not (List.exists (fun s -> s.item = line_item) stock) then
    J.fail "%sitem %s is not sold here." where line_item;
  if quantity < 1 || quantity > max_quantity then
    J.fail "%squantity is %d, not 1-%d." where quantity max_quantity;
  { line_item; quantity }

let of_args stocks ~where args =
  let map = J.string ~where "map" args in
  let stock =
    match stock stocks map with
    | Some s -> s
    | None -> J.fail "%smap %s is no Mart we know the stock of." where map
  in
  let lines = J.records ~where "items" args (line stock) in
  if lines = [] then J.fail "%sitems is empty." where;
  let budget =
    match J.find "budget" args with
    | Some (`Int b) -> Some b
    | None -> None
    | Some _ -> J.fail "%sbudget is not an int." where
  in
  { map; lines; budget }

type buy = { row : int; buy_item : string; buy_quantity : int; cost : int }

let row_of stock item =
  Option.get (List.find_index (fun s -> s.item = item) stock)

let cut_to left (b : buy) =
  match left with
  | None -> (b, None)
  | Some money ->
      let price = b.cost / b.buy_quantity in
      let n = min b.buy_quantity (money / price) in
      ({ b with buy_quantity = n; cost = n * price }, Some (money - (n * price)))

let buys stock plan =
  let full (l : line) =
    let row = row_of stock l.line_item in
    let price = (List.nth stock row).price in
    {
      row;
      buy_item = l.line_item;
      buy_quantity = l.quantity;
      cost = l.quantity * price;
    }
  in
  let _, cut =
    List.fold_left
      (fun (left, acc) l ->
        let b, left = cut_to left (full l) in
        (left, if b.buy_quantity > 0 then b :: acc else acc))
      (plan.budget, []) plan.lines
  in
  List.rev cut

let quantity_presses = Quantity_box.presses_from_one

let buy_to_string b =
  Printf.sprintf "%d %s (row %d, $%d)" b.buy_quantity b.buy_item b.row b.cost

let buys_to_string = function
  | [] -> "nothing"
  | bs -> String.concat "; " (List.map buy_to_string bs)
