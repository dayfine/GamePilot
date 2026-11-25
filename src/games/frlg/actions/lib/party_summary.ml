module P = Summary_paging

(* After LEFT back to the info page: its slide over, so the DOWN that follows
   is not dropped (the summary takes no DOWN while a page flips). *)
let flip_ms = 400

let read_pages ~log slot =
  let species = P.settled Party_species.read_shown in
  let level = P.settled Member_level.read_shown in
  P.to_page Summary_moves.moves_page;
  let moves = Summary_moves.settled_rows () in
  P.to_page 1;
  ignore (Effects.submit [ Wire.Wait { wait_ms = flip_ms } ] : Wire.batch_done);
  let member : Room_policy.member =
    {
      slot;
      species = Option.value species ~default:"?";
      level;
      moves = (if moves = [] then None else Some moves);
    }
  in
  log
    (Printf.sprintf "Party: slot %d is %s." slot
       (Room_policy.member_to_string member));
  member

let read_all ~log () =
  P.each_member ~label:"party summary" ~log (read_pages ~log)
