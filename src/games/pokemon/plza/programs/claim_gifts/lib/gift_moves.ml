module C = Plza_gift_catalog.Gift_catalog
module Cur = Box_cursor
module P = Box_paging

let ( let* ) = Result.bind
let party_six = (Cur.party_row, Cur.columns - 1)
let title_row = 2
let onto (s : C.box_slot) = Cur.of_slot s.slot
let to_title cur = Cur.go cur ~row:title_row ~col:0

(* Every cell of the box, row by row, each row read the short way from the
   last. *)
let cells =
  List.concat
    (List.init Cur.box_rows (fun r ->
         let cols = List.init Cur.columns Fun.id in
         List.map
           (fun c -> (r + 1, c))
           (if r mod 2 = 0 then cols else List.rev cols)))

let unread (_, r) = match r with Cur.Not_read _ -> true | _ -> false
let filled (c, r) = if r = Cur.Filled then Some c else None

(* The box's filled cells in reading order, or why not all read. *)
let scan cur =
  let read (row, col) = ((row, col), Cur.read cur ~row ~col) in
  let reads = List.map read cells in
  match List.find_opt unread reads with
  | Some ((row, col), _) ->
      Error (Printf.sprintf "row %d column %d not read" row (col + 1))
  | None -> Ok (List.sort compare (List.filter_map filled reads))

let why = function
  | Cur.Filled -> "it arrived"
  | Empty -> "the slot reads empty after it"
  | Not_read why -> why

(* Party slot 6 to [s], on Box 1. *)
let from_party ~log cur (s : C.box_slot) =
  match Cur.carry cur ~from:party_six ~onto:(onto s) with
  | Filled ->
      log (Printf.sprintf "Party slot 6 moved to Box 1 slot %d." s.slot);
      true
  | r ->
      log
        (Printf.sprintf "Party slot 6 not moved to Box 1 slot %d: %s." s.slot
           (why r));
      false

let to_box_one cur paging =
  to_title cur;
  P.back_to_box_one paging

(* On Box 1, the Pokémon in party slot 6 to [s]. *)
let on_to_slot ~log cur paging s =
  if from_party ~log cur s then Ok true
  else
    Error
      (Printf.sprintf "a Pokémon of Box %d stays in party slot 6"
         (P.opened_on paging))

(* One Pokémon of the open box to [s] by way of party slot 6, ending on Box 1;
   whether it arrived. *)
let carry_one ~log cur paging (cell, s) =
  let carried = Cur.carry cur ~from:cell ~onto:party_six in
  let* () = to_box_one cur paging in
  match carried with
  | Filled -> on_to_slot ~log cur paging s
  | r ->
      log
        (Printf.sprintf "Box %d's Pokémon not carried to party slot 6: %s."
           (P.opened_on paging) (why r));
      Ok false

let rec carry_all ~log cur paging moved = function
  | [] -> Ok moved
  | pair :: rest ->
      let* arrived = carry_one ~log cur paging pair in
      if not arrived then Ok moved
      else if rest = [] then Ok (moved + 1)
      else (
        to_title cur;
        let* () = P.to_opened paging in
        carry_all ~log cur paging (moved + 1) rest)

(* Why the open box's Pokémon are not taken for the gifts. *)
let not_taken ~box ~missing = function
  | Ok filled ->
      Printf.sprintf
        "Box %d holds %d Pokémon, not the %d gifts missing alone: none moved."
        box (List.length filled) (List.length missing)
  | Error e -> Printf.sprintf "Box %d not read (%s): none moved." box e

let from_opened ~log cur paging missing =
  let box = P.opened_on paging in
  to_title cur;
  let* () = P.to_opened paging in
  match scan cur with
  | Ok filled when List.length filled = List.length missing ->
      log
        (Printf.sprintf "Box %d holds %d Pokémon: the gifts missing." box
           (List.length filled));
      carry_all ~log cur paging 0 (List.combine filled missing)
  | found ->
      log (not_taken ~box ~missing found);
      let* () = to_box_one cur paging in
      Ok 0

let from_box ~log cur paging missing =
  if missing = [] then Ok 0
  else if P.opened_on paging = 1 then (
    log "The Boxes opened on Box 1: no other box to look in.";
    Ok 0)
  else from_opened ~log cur paging missing

let fill ~log cur paging ~in_party missing =
  match (missing, in_party) with
  | [], _ ->
      log "Every gift is in its slot.";
      Ok 0
  | s :: rest, true ->
      if from_party ~log cur s then
        Result.map (fun n -> n + 1) (from_box ~log cur paging rest)
      else Ok 0
  | _, false -> from_box ~log cur paging missing
