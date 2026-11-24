module J = Grid_maps.Json_field
module M = Menu_input
module S = Frlg_battle.Scripted_battle

type plan = {
  species : string;
  move : string;
  backup_move : string;
  pace : Grid_maps.Direction.t;
}

let decode =
  Action_args.decode ~action:"prepare_berry_pp" (fun ~where args ->
      {
        species = J.string ~where "species" args;
        move = J.string ~where "move" args;
        backup_move = J.string ~where "backup_move" args;
        pace = J.direction ~where "pace" args;
      })

let script ~move_slot ~backup_slot =
  Frlg_battle.Battle_script.make
    (Attack { slots = [ move_slot; backup_slot ]; target = Default })

let max_battles = 64

type rig = {
  lead : unit -> string option;
  known_moves : slot:int -> string list;
  find_battle : unit -> unit;
  battle : Frlg_battle.Battle_script.t -> S.outcome;
  log : string -> unit;
}

let lead_slot = 1

let slot_of known species move =
  match List.find_index (String.equal move) known with
  | Some i -> i
  | None ->
      M.fail "berry_pp_missing_move"
        (Printf.sprintf "%s knows no %s" species move)

(* One wild battle: [true] once the game refused the move in it. *)
let fight rig script n =
  rig.find_battle ();
  match rig.battle script with
  | S.Failed { why; _ } ->
      M.fail "berry_pp_battle_failed" (Printf.sprintf "battle %d: %s" n why)
  | S.Over summary ->
      rig.log
        (Printf.sprintf "Berry PP: battle %d %s." n
           (S.describe (S.Over summary)));
      summary.refusals > 0

let rec battles rig plan script n =
  if n > max_battles then
    M.fail "berry_pp_out_of_battles"
      (Printf.sprintf "%s still has PP after %d battles" plan.move max_battles)
  else if fight rig script n then
    rig.log
      (Printf.sprintf "Berry PP: %s has no PP left after %d battles." plan.move
         n)
  else battles rig plan script (n + 1)

let run rig plan =
  (match rig.lead () with
  | Some s when s = plan.species -> ()
  | lead ->
      M.fail "berry_pp_wrong_lead"
        (Printf.sprintf "%s leads, not %s"
           (Option.value lead ~default:"no one")
           plan.species));
  let known = rig.known_moves ~slot:lead_slot in
  let move_slot = slot_of known plan.species plan.move in
  let backup_slot = slot_of known plan.species plan.backup_move in
  battles rig plan (script ~move_slot ~backup_slot) 1
