type t = {
  mutable active_slot : int;
  party_order : int array;
  last_move_by_slot : (int, int) Hashtbl.t;
}

let visual_row_of tr slot =
  let len = Array.length tr.party_order in
  let rec loop i =
    if i >= len then max 0 (slot - 1)
    else if tr.party_order.(i) = slot then i
    else loop (i + 1)
  in
  loop 0

let swap_to tr slot =
  let row = visual_row_of tr slot in
  if row > 0 && row < Array.length tr.party_order then (
    let prev = tr.party_order.(0) in
    tr.party_order.(0) <- tr.party_order.(row);
    tr.party_order.(row) <- prev);
  tr.active_slot <- slot;
  row

let create ~party_size ~initial_active_slot =
  let tr =
    {
      active_slot = initial_active_slot;
      party_order = Array.init party_size (fun i -> i + 1);
      last_move_by_slot = Hashtbl.create party_size;
    }
  in
  ignore (swap_to tr initial_active_slot : int);
  tr

let active_slot tr = tr.active_slot

let last_move tr =
  Option.value ~default:1 (Hashtbl.find_opt tr.last_move_by_slot tr.active_slot)

let record_move tr move_slot =
  Hashtbl.replace tr.last_move_by_slot tr.active_slot move_slot
