module M = Pokemon_home.Box_moves
module B = Pokemon_home.Box_view
module F = Json_field

let ( let* ) = Result.bind
let home_box_most = 300
let move_fields = [ "gift"; "box_slot"; "home_boxes"; "scan" ]

let known_only ~where ~what fields obj =
  match List.find_opt (fun (k, _) -> not (List.mem k fields)) obj with
  | Some (k, _) -> F.fail "%s%s is not a field of %s" where k what
  | None -> ()

let scan_of ~where = function
  | "left_to_right" -> B.Left_to_right
  | "right_to_left" -> B.Right_to_left
  | s -> F.fail "%sscan is left_to_right or right_to_left, not %s" where s

let int_item ~where key = function
  | `Int n -> n
  | _ -> F.fail "%s%s holds whole numbers" where key

let ints ~where key obj =
  List.map (int_item ~where key)
    (Option.value ~default:[] (F.list_opt ~where key obj))

let game_col ~where obj =
  let slot = F.int ~where "box_slot" obj in
  if slot < 1 || slot > B.columns then
    F.fail "%sbox_slot is 1 to %d (Box 1's first row), not %d" where B.columns
      slot
  else slot - 1

let move ~where obj : M.t =
  known_only ~where ~what:"a move" move_fields obj;
  {
    name = F.string ~where "gift" obj;
    game_col = game_col ~where obj;
    boxes = ints ~where "home_boxes" obj;
    order = scan_of ~where (F.string ~where "scan" obj);
  }

let decode args =
  F.catch (fun () ->
      known_only ~where:"" ~what:"bank_in_home's args (moves)" [ "moves" ] args;
      F.records ~where:"" "moves" args move)

let in_range b = b >= 1 && b <= home_box_most

let out_of_range ~what b =
  Error (Printf.sprintf "%s: HOME box %d is not 1 to %d" what b home_box_most)

let check_boxes ~what boxes =
  match (boxes, List.find_opt (fun b -> not (in_range b)) boxes) with
  | [], _ -> Error (what ^ ": no HOME box")
  | _, Some b -> out_of_range ~what b
  | _, None -> Ok boxes

let rec all_ok = function
  | [] -> Ok []
  | Ok x :: rest -> Result.map (fun xs -> x :: xs) (all_ok rest)
  | Error e :: _ -> Error e

let rec twice = function
  | [] -> None
  | x :: rest -> if List.mem x rest then Some x else twice rest

let distinct ~what key moves =
  match twice (List.map key moves) with
  | Some x -> Error (Printf.sprintf "two moves of %s %s" what x)
  | None -> Ok ()

let check_moves (moves : M.t list) =
  let* () = if moves = [] then Error "moves: no move" else Ok () in
  let* () = distinct ~what:"the gift" (fun (m : M.t) -> m.name) moves in
  let* () =
    distinct ~what:"box_slot"
      (fun (m : M.t) -> string_of_int (m.game_col + 1))
      moves
  in
  all_ok
    (List.map
       (fun (m : M.t) ->
         Result.map
           (fun _ -> m)
           (check_boxes ~what:(m.name ^ "'s home_boxes") m.boxes))
       moves)

let of_args args = Result.bind (decode args) check_moves
